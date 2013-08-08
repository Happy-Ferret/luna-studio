#!/usr/bin/python
import os.path
import sys
from subprocess import call, Popen, PIPE

dir = os.path.dirname(os.path.realpath(__file__))
third_party = os.path.join(dir, 'third-party')
p_thrift   = os.path.join(third_party,  'thrift-0.9')
p_luna     = os.path.join(dir, 'libs',  'luna')
p_batch    = os.path.join(dir, 'libs',  'batch')
p_batchsrv = os.path.join(dir, 'tools', 'batch-srv')
p_lunac    = os.path.join(dir, 'tools', 'lunac')


def check(name):
	print "Checking if '%s' is installed" % name
	(out, err) = Popen(name, stdout=PIPE, shell=True).communicate()
	if not out:
		print "Please install '%s' to continue" % name
		sys.exit()	

check('cabal-dev')

print "Registering thrift library"
if call(['cabal-dev', 'add-source', p_thrift]):
	sys.exit()

print "Compiling projects"
call(['cabal-dev', 'install', p_luna, p_batch, p_batchsrv, p_lunac])

