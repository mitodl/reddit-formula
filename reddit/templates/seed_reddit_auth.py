#!/usr/bin/env python

from r2.models import Account, register, OAuth2Client, change_password
from r2.lib.db import thing
from r2.lib.db import tdb_cassandra

try:
    devops = Account._by_name('odldevops')
    change_password(devops, '{{ account_password}}')
except thing.NotFound:
    devops = register('odldevops', '{{ account_password }}', '127.0.0.1')

try:
    client = OAuth2Client._byID('{{ oauth_client_id }}')
except tdb_cassandra.NotFound:
    client = OAuth2Client(_id='{{ oauth_client_id }}',
                          secret='{{ oauth_client_secret }}',
                          redirect_uri='https://discussions.odl.mit.edu',
                          name='Client app for open discussions',
                          app_type='script')
client.add_developer(devops)
client._commit()
