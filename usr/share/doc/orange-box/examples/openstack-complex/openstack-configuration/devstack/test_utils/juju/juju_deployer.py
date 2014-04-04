import logging
import os
import paramiko
import shutil
import time
import yaml

from deployer.config import ConfigStack
from deployer.action import importer
from deployer.env import select_runtime
from deployer.utils import setup_logging

# SSH user for collecting log artifacts
REMOTE_USER = 'ubuntu'

# SSH Command to use for collecting artifacts on every node
REMOTE_LOG_CMD = "sudo tar -czf /tmp/%s-%s-artifacts.tar.gz /etc /var/log"


class Config(object):
    # what juju-deployer would typically take as argparse
    no_local_mods = False
    update_charms = False
    overrides = None
    branch_only = False
    timeout = 1800
    watch = True
    verbose = True
    debug = True
    rel_wait = 240
    bootstrap = True
    retry_count = None
    deploy_delay = 0


def run_deployer(environment, configs, deployment, **kwargs):
    '''
    Uses juju-deployer to deploy a deployment from a given config(s)
    into an already deployed environment.

    Example usage:
        run_deployer(
            environment='precise',
            configs=['/tmp/base.cfg'],
            deployment='precise-grizzly',
            debug=True, verbose=True
        )
    '''
    opts = Config()

    setup_logging(
        verbose=kwargs.get('verbose', False),
        debug=kwargs.get('debug', False),
    )

    if 'overrides' in kwargs:
        opts.overrides = kwargs['overrides']

    for conf in configs:
        if not os.path.isfile(conf):
            e = 'Could not find deployment config @ %s.' % conf
            raise Exception(e)

    env = select_runtime(environment, opts)
    config = ConfigStack(configs)
    deploy = config.get(deployment)
    importer.Importer(env, deploy, options=opts).run()


def reset(environment):
    env = select_runtime(environment, Config())
    env.connect()
    env.reset(terminate_machines=True, terminate_delay=6, watch=True,
              timeout=600)


def locate_machine(status, machine_id):
    '''determine service unit assigned to machine id'''
    if machine_id == '0':
        return 'bootstrap-machine-0'
    services = status['services']
    for unit in [services[k]['units'] for k in services.iterkeys()]:
        if machine_id in [u['machine'] for u in unit.itervalues()]:
            return [k for k in unit.iterkeys()][0].replace('/', '-')
    return None


def hosts_services(status):
    machines = []
    for id, machine in status['machines'].iteritems():
        if 'dns-name' not in machine:
            logging.error('Machine %s has no dns-name.' % id)
            logging.error(machine)
            continue
        m = {'id': id, 'dns-name': machine['dns-name']}
        machines.append(m)
    [m.update({'service': locate_machine(status, m['id'])})
     for m in machines]
    return machines


def collect_artifacts(environment, outdir):
    if not os.path.exists(outdir):
        os.makedirs(outdir)
    if not os.path.isdir(outdir):
        raise Exception('%s exists but is not a directory.' % outdir)

    env = select_runtime(environment, Config())

    conns = {}
    hosts = hosts_services(env.get_cli_status())

    logging.info('Collecting artifacts from %s.' %
                 [h['dns-name'] for h in hosts])

    for host in hosts:
        hn = host['dns-name']

        conns[hn] = {}
        conns[hn]['ssh'] = paramiko.SSHClient()
        conns[hn]['ssh'].set_missing_host_key_policy(paramiko.AutoAddPolicy())

        try:
            conns[hn]['ssh'].connect(hn, username=REMOTE_USER)
            conns[hn]['sftp'] = conns[hn]['ssh'].open_sftp()
        except Exception as e:
            raise Exception('Could not setup ssh connection to %s: %s' %
                            (hn, e))

    for host in hosts:
        hn = host['dns-name']
        svc = host['service']
        cmd = REMOTE_LOG_CMD % (svc, hn)
        try:
            conns[hn]['ssh'].exec_command(cmd)
        except Exception as e:
            logging.error('Could not execute remote log cmd on '
                          'host %s: %s' % (hn, cmd))
            raise e

    # sleep for 5, allow all hosts to finish tarring.
    time.sleep(5)

    for host in hosts:
        hn = host['dns-name']
        svc = host['service']
        try:
            tgz = '%s-%s-artifacts.tar.gz' % (svc, hn)
            conns[hn]['sftp'].get(
                os.path.join('/tmp', tgz), os.path.join(outdir, tgz))
        except Exception as e:
            logging.error('Could not collect artifacts from %s:%s' %
                          (hn, tgz))
            raise e

    # collect the local maas logs if they exist
    if os.path.isdir('/var/log/maas'):
        for log in ['maas.log', 'pserv.log']:
            l = os.path.join('/var/log/maas', log)
            if os.path.isfile(l):
                shutil.copy(l, outdir)

    # dump current juju status
    with open(os.path.join(outdir, 'juju_status.yaml'), 'w') as out:
        out.write(yaml.dump(env.get_cli_status()))


class DeployerTest(object):
    def __init__(self):
        self.config = None

    def deploy(self, env=None):
        env = env or self.config.get('ubuntu_release')
        run_deployer(environment=env,
                     configs=[self.config.get('deployment_config')],
                     deployment=self.config.get('deployment'),
                     overrides=self.config.get('overrides'),
                     debug=True, verbose=True)

    def reset_environment(self, env=None):
        _env = env or self.config.get('ubuntu_release')
        reset(_env)

    def collect_artifacts(self, env, outdir):
        _env = env or self.config.get('ubuntu_release')
        collect_artifacts(_env, outdir)
