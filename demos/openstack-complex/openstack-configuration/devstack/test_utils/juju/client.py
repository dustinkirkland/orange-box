# Some simple helpers to wrap the juju client, mostly borrowed
# from Kapil's charmrunner: lp:~hazmat/+junk/charmrunner

import json
import subprocess
import logging
import time
import yaml


class JujuTestClientException(Exception):
    pass


def call(juju_cmd, environment=None):
    cmd = ['juju']
    if environment:
        cmd += ['-e', environment]
    cmd += juju_cmd
    logging.debug('Calling: %s' % ' '.join(cmd))
    print 'juju client: %s' % cmd
    subprocess.check_output(cmd)


def destroy_environment(sudo=False):
    logging.debug('Destroying environment.')
    cmd = ['juju', 'destroy-environment', '-y']
    if sudo:
        cmd = ['sudo'] + cmd
    p = subprocess.Popen(cmd,
                         stdout=subprocess.PIPE, stdin=subprocess.PIPE,
                         stderr=subprocess.PIPE)
    print p.communicate(input='y\n')[0]


def status(environment=None, with_stderr=False, timeout=None):
    """Get a status dictionary.
    """
    args = ["juju", "status", "--format=json"]

    if timeout:
        args = ['timeout', str(timeout)] + args

    if environment:
        args += ['-e', environment]

    if with_stderr:
        output = subprocess.check_output(args, stderr=subprocess.STDOUT)
        return output
    else:
        output = subprocess.check_output(args, stderr=open("/dev/null"))
        return json.loads(output)


def is_bootstrapped(environment=None, timeout=None):
    try:
        _status = status(environment=environment, with_stderr=False,
                         timeout=timeout)
    except:
        return False

    try:
        return _status['machines']['0']['agent-state'] == 'started'
    except KeyError:
        return False


def deploy(repo_dir, charm, environment=None, service=None, config=None,
           args=[]):
    '''
    Deploy a charm as a service.
    '''
    cmd = ["juju", "deploy",
           "--repository", repo_dir]
    if config:
        cmd += ['--config=%s' % config]
    if environment:
        cmd += ['-e', environment]
    [cmd.append(a) for a in args]
    cmd += ["local:%s" % charm]
    if service:
        cmd += [service]
    output = subprocess.check_output(cmd, stderr=subprocess.STDOUT)
    logging.info("Deployed %s" % (service or charm))
    return output


def get_config(service):
    args = ['juju', 'get', service]
    output = subprocess.check_output(args, stderr=open('/dev/null'))
    return yaml.load(output)


def services(environment=None):
    '''yield (name, address, state) for every service deployed.  this assumes
       a single machine unit per service'''
    _status = status(environment)
    for service, info in _status['services'].iteritems():
        unit = info['units'].keys()[0]
        m_id = str(info['units'][unit]['machine'])
        try:
            dns_name = _status['machines'][m_id]['dns-name']
        except KeyError:
            dns_name = None
        state = info['units'][unit]['agent-state']
        yield (service, dns_name, state)


def get_machine_unit(service_name, environment=None):
    for service, address, state in services(environment):
        if service == service_name:
            return address


def instance_ids():
    _status = status()
    return [_status['machines'][n]['instance-id'] for n in _status['machines']]


def ensure_bootstrap(environment=None, constraints=None, timeout=180,
                     sudo=False):
    '''
    Bootstrap and wait for a started environment within timeout specified.
    Bootstrapping may require sudo access (ie, local provider)
    '''

    if is_bootstrapped(environment, timeout=5):
        logging.info('Environment Already bootstrapped.')
        return True

    cmd = ['juju', 'bootstrap']
    if environment:
        cmd += ['-e', environment]
    if constraints:
        cmd += ['--constraints', constraints]

    if sudo:
        cmd = ['sudo'] + cmd

    logging.info('Boostrapping new environment')
    try:
        subprocess.check_output(cmd)
    except:
        logging.error('Calling "juju bootstrap" failed!')

    i = 0
    while not is_bootstrapped(environment, timeout=5):
        if i >= timeout:
            logging.error('Juju bootstrap timeout.')
            raise JujuTestClientException
        time.sleep(1)
        i += 1

    return True


def wait_for_state(service, state, environment=None, timeout=180):
    logging.debug('Waiting for service %s to reach state %s.' %
                  (service, state))
    i = 0
    while True:
        _status = status(environment)
        if service not in _status['services']:
            logging.error('wait_for_state: Could not find service ' + service)
            raise JujuTestClientException
        _st = list(set([_status['services'][service]['units'][u]['agent-state']
                   for u in _status['services'][service]['units']]))
        if 'error' in _st:
            logging.error('Unit error while waiting for %s to reach state %.'
                          % (service, state))
            raise JujuTestClientException
        if _st == [state]:
            return True
        if i >= timeout:
            logging.error('Timeout waiting for service %s to reach state: %s' %
                          (service, state))
            raise JujuTestClientException
        time.sleep(1)
        i += 1


def service_machine_units(service, environment=None):
    _status = status()
    try:
        _service = _status['services'][service]
    except KeyError:
        logging.error('Could not find machine units for unknown service %s' %
                      service)
        raise JujuTestClientException
    return [_service['units'][u]['machine'] for u in _service['units']]
