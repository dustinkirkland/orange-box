import ConfigParser
import os
import subprocess
import logging
import jinja2

from test_utils.config import CloudConfig

cloud_config = CloudConfig()

DEFAULT_CONFIG='etc/devstack.conf'
DEFAULT_WORK_DIR=os.path.join(os.environ['HOME'], 'devstack-test')

class DevstackConfig(object):
    def __init__(self, conf=DEFAULT_CONFIG, work_dir=DEFAULT_WORK_DIR):
        self.config = ConfigParser.SafeConfigParser()
        self.config.read(conf)

        self.work_dir = work_dir
        if not os.path.exists(self.work_dir):
            os.makedirs(self.work_dir)

        self.devstack_dir = os.path.join(self.work_dir, 'devstack')
        self.git_repo = self.config.get('DEFAULT', 'devstack_repo')

        templ_dir = self.config.get('DEFAULT', 'templates')
        templ_dir = os.path.join(os.getcwd(), templ_dir)
        if not os.path.exists(templ_dir):
            logging.error('Could not locate devstack template directory @ %s'\
                        % templ_dir)
            raise
        loader = jinja2.FileSystemLoader(templ_dir)
        self.templates = jinja2.Environment(loader = loader)
        self.git_branch = self.config.get('DEFAULT', 'devstack_branch')

    def get(self, item, section='DEFAULT'):
        return self.config.get(section, item)

    def prepare_devstack(self):
        self._clone_devstack(directory=self.devstack_dir)
        self._write_openrc(branch=self.git_branch, directory=self.devstack_dir)
        self._write_exerciserc()

    def _clone_devstack(self, directory=None, branch=None):
        if not directory:
            directory = self.devstack_dir
        if not branch:
            branch = self.git_branch
        cmd = [ 'git', 'clone', self.git_repo, directory ]
        subprocess.check_output(cmd)

        if branch != 'master':
            os.chdir(directory)
            cmd = [ 'git', 'checkout', branch ]
            subprocess.check_output(cmd)

    def _write_openrc(self, branch='master', directory=None):
        ''' Write openrc template to specified directory.
            branch is definied in config.
            branch names are expected to be in git format.
            _'s will be substited for /'s in template name,
            ie, branch='stable/essex' -> $directory/openrc.stable_essex
        '''
        if not directory:
            directory = self.devstack_dir
        git_branch = ""
        for i in branch:
            if i == '/':
                git_branch += '_'
            else:
                git_branch += i

        openrc = os.path.join(directory, 'openrc')
        templ = self.templates.get_template('openrc.%s' % git_branch)
        context = { 'nova_host': cloud_config.get('DEFAULT', 'nova_host'),
                    'glance_host': cloud_config.get('DEFAULT', 'glance_host'),
                    'keystone_host': cloud_config.get('DEFAULT', 'keystone_host'),
                    'service_host': cloud_config.get('DEFAULT', 'service_host'),
                    'os_username': cloud_config.get('osapi', 'username'),
                    'os_password': cloud_config.get('osapi', 'password'),
                    'os_tenant_name': cloud_config.get('osapi', 'tenant_name'),
                    'secondary_ip_pool': self.get('secondary_ip_pool'),
                    'enabled_services': self.get('enabled_services')
                  }
        f = open(openrc, 'w')
        f.write(templ.render(context))
        f.close()

    def _write_exerciserc(self, directory=None):
        ''' Write out the exerciserc file based on whats in config.'''
        if not directory:
            directory = self.devstack_dir
        exerciserc = os.path.join(directory, 'exerciserc')
        templ = self.templates.get_template('exerciserc')
        context = { 'active_timeout': self.get('active_timeout'),
                    'associate_timeout': self.get('associate_timeout'),
                    'boot_timeout': self.get('boot_timeout'),
                    'running_timeout': self.get('running_timeout'),
                    'terminate_timeout': self.get('terminate_timeout')
        }
        f = open(exerciserc, 'w')
        f.write(templ.render(context))
        f.close()
