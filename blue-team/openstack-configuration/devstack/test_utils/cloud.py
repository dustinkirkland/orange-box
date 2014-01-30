
import json
import urlparse
import uuid
import sys
import time
import logging
from copy import copy, deepcopy

from openstack_ubuntu_testing.test_utils.config import CloudConfig

from boto import exception, connect_ec2
from boto.ec2.regioninfo import RegionInfo

from novaclient.v1_1.client import Client as OSNovaClient
from cinderclient.v1.client import Client as OSCinderClient

INST_RUN_TIMEOUT = 120
INST_TERMINATE_TIMEOUT=60
VOL_CREATE_TIMEOUT = 30
VOL_ATTACH_TIMEOUT = 30

def _normalize_ec2(d):
    '''convert all values of dict to a string'''
    out = {}
    for k, v in out.iteritems():
        if 'object at' in str(v):
            out.pop(k)
        elif isinstance(v, dict):
            out[k] = _normalize_ec2(v)
        else:
            out[k] = str(v)
    return out


def _normalize_osapi(d):
    '''
    'ensure everythign in dict is a string, and remove any object references.
    '''
    out = {}
    # these are known to hold references to objects in memory, remove them.
    black_list = ['manager']
    for k, v in d.iteritems():
        if k in black_list:
            continue
        out[k] = str(v)
    return out



_resources = {
    'ec2': {
        'instances': [],
        'floating_ips': [],
        'key_pairs': [],
        'volumes': [],
    },
    'osapi': {
        'instances': [],
        'floating_ips': [],
        'key_pairs': [],
        'volumes': [],
    }
}

class EC2CloudClient(object):
    def __init__(self, access_key, secret_key, endpoint):
        url = urlparse.urlparse(endpoint)
        sec = False
        if url.scheme == 'https':
            sec = True
        region = RegionInfo(name='nova', endpoint=url.hostname)
        self.api = connect_ec2(access_key, secret_key, host=url.hostname,
                          port=url.port, path=url.path, is_secure=sec,
                          region=region)

        # track IDs of created resources for tear-down.
        self.instances = []
        self.key_pairs = []
        self.floating_ips =[]
        self.volumes = []

    def instance_ids(self):
        ids = []
        for reservation in self.api.get_all_instances():
            [ids.append(i.id) for i in reservation.instances]
        return ids

    def instances_running(self, instance_ids=[]):
        '''given a list of instance_ids, return list of only running instances'''
        running = []
        reservations = []
        for id in instance_ids:
            try:
                reservations.append(self.api.get_all_instances(instance_ids=str(id)))
            except exception.EC2ResponseError:
                instance_ids.remove(id)

        instances = []
        for r in reservations:
            if len(r) > 0 and r[0].instances:
                instances.append(r[0].instances[0])

        for instance in instances:
            if instance.state == 'running':
                running.append(instance.id)
        return running


    def get_images(self):
        images = {}
        [images.update({i.id: _normalize_ec2(vars(i))})
         for i in self.api.get_all_images()]
        return images


    def get_key_pairs(self):
        kps = {}
        [kps.update({k.name: _normalize_ec2(vars(k))})
         for k in self.api.get_all_key_pairs()]
        return kps


    def get_instances(self):
        insts = {}
        for reservation in self.api.get_all_instances():
            [insts.update({i.id: _normalize_ec2(vars(i))})
             for i in reservation.instances]
        return insts


    def get_floating_ips(self):
        ips = {}
        [ips.update({ip.public_ip:  _normalize_ec2(vars(ip))})
         for ip in self.api.get_all_addresses()]
        return ips


    def get_volumes(self):
        vols = {}
        [vols.update({v.id: _normalize_ec2(vars(v))})
         for v in self.api.get_all_volumes()]
        return vols


    def create_key_pair_and_instance(self):
        '''
        create a key_pair, launch an instance with it, wait for it
        to start
        '''
        kp_name = 'upgrade_key_pair_%s' % uuid.uuid1()
        kp = self.api.create_key_pair(key_name=kp_name)
        self.key_pairs.append(kp_name)

        imgs = self.api.get_all_images()
        img_id = None
        for img in imgs:
            if img.id.startswith('ami-'):
                img_id = img.id
                break

        res = self.api.run_instances(img_id, key_name=kp_name,
                                     instance_type='m1.tiny')
        time.sleep(1)
        instance_id = res.instances[0].id
        self.instances.append(instance_id)

        timeout = 0

        while instance_id not in self.instances_running([instance_id]):
            time.sleep(1)
            timeout += 1
            if timeout >= INST_RUN_TIMEOUT:
                logging.error('Timed out waiting for instance to run: %s' %\
                               instance_id)
                raise Exception
        logging.info('Instance running: %s' % instance_id)


    def create_and_associate_floating_ip(self):
        instance_id = self.instance_ids().pop()
        address = self.api.allocate_address()
        self.floating_ips.append(address.public_ip)
        self.api.associate_address(instance_id, public_ip=address.public_ip)


    def create_and_attach_volume(self):
        instance_id = self.instance_ids().pop()
        volume = self.api.create_volume(size=1, zone='nova')
        self.volumes.append(volume.id)
        time.sleep(1)
        timeout = 0
        while timeout <= VOL_CREATE_TIMEOUT:
            vol = self.api.get_all_volumes(volume_ids=[volume.id])
            if vol and vol[0].status == 'available':
                break
            timeout += 1
            time.sleep(1)
        print 'created vol: %s' %volume.id

        self.api.attach_volume(volume_id=volume.id, instance_id=instance_id,
                               device='/dev/vdb')
        timeout = 0
        while timeout <= VOL_ATTACH_TIMEOUT:
            vol = self.api.get_all_volumes(volume_ids=[volume.id])
            if vol and vol[0].status == 'in-use':
                break
            timeout += 1
            time.sleep(1)


    def teardown(self):
        self.api.terminate_instances(self.instances)
        timeout = 0
        while self.instances_running(self.instances):
            if timeout >= INST_TERMINATE_TIMEOUT:
                logging.error('Timeout waiting for instances terminate: %s' %\
                              self.instances)
                raise Exception
            timeout += 1
            time.sleep(1)
        [self.api.delete_key_pair(k) for k in self.key_pairs]
        [self.api.release_address(ip)
         for ip in self.floating_ips]
        [self.api.delete_volume(vol) for vol in self.volumes]


class OSAPICloudClient(object):
    def __init__(self, username, password, tenant_name, auth_url):
        self.compute_api = OSNovaClient(username, password,
                                        tenant_name, auth_url, no_cache=True)
        self.volume_api = OSCinderClient(username, password,
                                         tenant_name, auth_url)
        # track IDs of created resources for tear-down.
        self.instances = []
        self.key_pairs = []
        self.floating_ips =[]
        self.volumes = []

    def instance_ids(self):
        return [inst.id for inst in self.compute_api.servers.list()]

    def instances_running(self, instance_ids=[]):
        '''given a list of instance_ids, return list of only running instances'''
        running = []
        for id in instance_ids:
            if id in [i.id for i in self.compute_api.servers.list()]:
                running.append(id)

        for id in running:
            inst = self.compute_api.servers.get(id)
            if inst.status != 'ACTIVE':
                running.remove(id)
        return running

    def get_images(self):
        images = {}
        [images.update({i.id: _normalize_osapi(vars(i))})
         for i in self.compute_api.images.list()]
        return images

    def get_key_pairs(self):
        kps  = {}
        [kps.update({k.id: _normalize_osapi(vars(k))})
         for k in self.compute_api.keypairs.list()]
        return kps

    def get_instances(self):
        insts = {}
        [insts.update({i.id: _normalize_osapi(vars(i))})
         for i in self.compute_api.servers.list()]
        return insts

    def get_floating_ips(self):
        ips = {}
        [ips.update({i.id: _normalize_osapi(vars(i))})
         for i in self.compute_api.floating_ips.list()]
        return ips


    def get_volumes(self):
        vols = {}
        [vols.update({v.id: _normalize_osapi(vars(v))})
         for v in self.volume_api.volumes.list()]
        return vols


    def create_key_pair_and_instance(self):
        kp_name = 'upgrade_key_pair_%s' % uuid.uuid1()
        inst_name = 'upgrade_instance_%s' % uuid.uuid1()
        image_id = self.get_images().keys().pop()
        kp = self.compute_api.keypairs.create(name=kp_name)
        instance = self.compute_api.servers.create(name=inst_name, flavor=1,
                                                   image=image_id,
                                                   key_name=kp_name)
        timeout = 0
        while self.compute_api.servers.get(instance.id).status != 'ACTIVE':
            if timeout >= INST_RUN_TIMEOUT:
                logging.error('Timed out waiting for instance to run: %s' %\
                               instance.name)
                raise Exception
            timeout += 1
            time.sleep(1)

        self.instances.append(instance.id)
        self.key_pairs.append(kp_name)


    def create_and_associate_floating_ip(self):
        instance = self.compute_api.servers.list().pop()
        floating_ip = self.compute_api.floating_ips.create()
        self.floating_ips.append(floating_ip.ip)
        instance.add_floating_ip(floating_ip.ip)


    def create_and_attach_volume(self):
        instance = self.compute_api.servers.list().pop()
        volume = self.volume_api.volumes.create(size=1)
        self.volumes.append(volume.id)
        # TODO volume attach requires cinder.


    def teardown(self):
        for instance in self.instances:
            self.compute_api.servers.delete(instance)

        timeout = 0
        while self.instances_running(self.instances):
            if timeout >= INST_TERMINATE_TIMEOUT:
                logging.error('Timeout waiting for instances terminate: %s' %\
                              self.instances)
                raise Exception
            timeout += 1
            time.sleep(1)
        [self.compute_api.keypairs.delete(kp)
         for kp in self.key_pairs]
        [self.volume_api.volumes.delete(v)
         for v in self.volumes]


def create_snapshot(client):
    snapshot = {}
    for collection in ['images', 'key_pairs', 'instances', 'floating_ips',
                       'volumes']:
        f = 'get_%s' % collection
        if not hasattr(client, f):
            logging.warning('CloudClient (%s) does not implement %s' %\
                            (client, f))
        f = getattr(client, f)
        snapshot[collection] = f()
    return snapshot
