import unittest
import shutil
import os
import nose
import subprocess
import sys
import logging

from test_utils.config import CloudConfig
from config import DevstackConfig

WORK_DIR='/tmp/devstack-test'

cloud_config = CloudConfig()

class DevstackExcercises(unittest.TestCase):
    @classmethod
    def setUpClass(self):
        try:
            self.artifacts_dir = cloud_config.get('tests', 'artifacts_dir')
        except:
            self.artifacts_dir = None
        if self.artifacts_dir:
            if os.path.isdir(self.artifacts_dir):
                shutil.rmtree(self.artifacts_dir)
            os.mkdir(self.artifacts_dir)
        if os.path.exists(WORK_DIR):
            logging.debug("Removing existing work_dir @ %s" % WORK_DIR)
            shutil.rmtree(WORK_DIR)
        self.devstack  = DevstackConfig(work_dir=WORK_DIR)
        self.devstack.prepare_devstack()


    def _call_exercise(self, exercise):
        os.chdir(self.devstack.devstack_dir)
        exercise_script = './exercises/%s' % exercise

        if not os.path.isfile(exercise_script):
            # Skip exercise if it is not found (its probably hosted
            #  in another branch of devstack)
            raise nose.SkipTest('Skipping %s, exercise script not found in '\
                                ' this branch.' % exercise_script)

        try:
            archive_logs = cloud_config.get('tests', 'archive_logs')
        except:
            archive_logs = False

        if archive_logs in ['True', 'true']:
            log = os.path.join(self.artifacts_dir, 'devstack_ex_%s.log' %\
                               exercise)
            log = open(log, 'wb')
            t_stdout = t_stderr = log
        else:
            t_stdout = t_stderr = subprocess.PIPE

        p = subprocess.Popen(exercise_script,
                             stdout=t_stdout, stderr=t_stderr)
        p.poll()
        (stdout, stderr) = p.communicate()
        if p.returncode == 0:
            return True
        elif p.returncode == 55:
            # Exercises that return 55 do so because the target service is
            # not enabled, via ENABLED_SERVICES.
            raise nose.SkipTest('Service not enabled, skipping test.')
        else:
            logging.debug('--- Exercise %s failed with RC %s.'\
                           % (exercise,  p.returncode))
            logging.debug('Debug output:')
            logging.debug(stdout)
            logging.debug(stderr)
            return False

    def test_aggregates(self):
        '''test_aggregates: Test host aggregates'''
        self.assertTrue(self._call_exercise('aggregates.sh'))

    def test_client_env(self):
        '''test_client_env: Test OpenStack client enviroment variable handling'''
        self.assertTrue(self._call_exercise('client-env.sh'))

    def test_floating_ips(self):
        '''test_floating_ips: Test instance spawn + IP association via OSAPI'''
        self.assertTrue(self._call_exercise('floating_ips.sh'))

    def test_volumes(self):
        '''test_volumes: Test instance spawn + volume attachment via OSAPI'''
        self.assertTrue(self._call_exercise('volumes.sh'))

    def test_sec_groups(self):
        '''test_sec_groups: Test security groups via the command line tools'''
        self.assertTrue(self._call_exercise('sec_groups.sh'))

    def test_horizon(self):
        '''test_horizon: Ensure horizon displays a login page.'''
        self.assertTrue(self._call_exercise('horizon.sh'))

    def test_boot_from_volume(self):
        '''test_boot_from_volume: Test instance spawn from cinder volume.'''
        self.assertTrue(self._call_exercise('boot_from_volume.sh'))

    def test_swift(self):
        '''test_swift: Ensure swift object storage if functional.'''
        self.assertTrue(self._call_exercise('swift.sh'))
