
import ConfigParser

DEFAULT_CONFIG = 'etc/openstack.conf'


class CloudConfig(object):
    def __init__(self, conf=None):
        if not conf:
            conf = DEFAULT_CONFIG
        self.config = ConfigParser.SafeConfigParser()
        self.config.read(conf)

    def get(self, section=None, item=None):
        if not section:
            section = 'DEFAULT'
        return self.config.get(section, item)

    def enabled_services(self):
        '''translate ENABLED_SERVICES to corresponding juju OS service names.
        '''
        service_map = {
            'n-api': 'nova-cloud-controller',
            'n-crt': 'nova-cloud-controller',
            'n-obj': 'nova-cloud-controller',
            'n-sch': 'nova-cloud-controller',
            'g-api': 'glance',
            'g-reg': 'glance',
            'key': 'keystone',
            'cinder': 'cinder',
            'c-api': 'cinder',
            'c-vol': 'cinder',
            'horizon': 'openstack-dashboard',
            'n-net': 'nova-compute',
            'quantum': 'quantum'
        }
        env = self.get('DEFAULT', 'enabled_services').split(',')
        enabled_services = []
        for svc in env:
            try:
                service = service_map[svc]
                if service not in enabled_services:
                    enabled_services.append(service)
            except KeyError:
                pass
        return enabled_services
