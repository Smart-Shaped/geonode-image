#!/usr/bin/env python

#########################################################################
#
# Copyright (C) 2024 OSGeo
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
#########################################################################

import os
from django.core.management.base import BaseCommand
from django.conf import settings
from allauth.socialaccount.models import SocialApp
from django.contrib.sites.models import Site


class Command(BaseCommand):
    help = 'Initialize Keycloak Social Application for django-allauth'

    def add_arguments(self, parser):
        parser.add_argument(
            '--no-input',
            action='store_true',
            help='Do not prompt for input during automatic setup',
        )

    def handle(self, *args, **options):
        """
        Create or update the Keycloak Social Application
        """
        site = Site.objects.get_current()
        
        # Get Keycloak configuration from environment
        client_id = os.getenv("KEYCLOAK_CLIENT_ID")
        client_secret = os.getenv("KEYCLOAK_CLIENT_SECRET")
        
        if not client_id or not client_secret:
            self.stdout.write(
                self.style.ERROR(
                    'KEYCLOAK_CLIENT_ID and KEYCLOAK_CLIENT_SECRET must be set in environment variables'
                )
            )
            return
        
        # Create or update Keycloak Social App
        social_app, created = SocialApp.objects.get_or_create(
            provider='geonode_openid_connect',
            name='Keycloak',
            defaults={
                'client_id': client_id,
                'secret': client_secret,
            }
        )
        
        if not created:
            # Update existing app
            social_app.name = 'Keycloak'
            social_app.client_id = client_id
            social_app.secret = client_secret
            social_app.save()
            
        # Add site to the social app
        social_app.sites.add(site)
        
        action = "Created" if created else "Updated"
        
        if options.get('no_input'):
            # Messaggio compatto per esecuzione automatica
            self.stdout.write(f'✅ Keycloak Social App {action.lower()}')
        else:
            # Messaggio completo per esecuzione manuale
            self.stdout.write(
                self.style.SUCCESS(
                    f'{action} Keycloak Social Application with client_id: {client_id}'
                )
            )
        
        # Display configuration summary
        self.stdout.write('\nKeycloak Configuration Summary:')
        self.stdout.write(f'- Server URL: {os.getenv("KEYCLOAK_SERVER_URL", "Not set")}')
        self.stdout.write(f'- Realm: {os.getenv("KEYCLOAK_REALM", "Not set")}')
        self.stdout.write(f'- Client ID: {client_id}')
        self.stdout.write(f'- Authorization URL: {os.getenv("OIDC_AUTHORIZE_URL", "Not set")}')
        self.stdout.write(f'- Token URL: {os.getenv("OIDC_ACCESS_TOKEN_URL", "Not set")}')
        self.stdout.write(f'- UserInfo URL: {os.getenv("OIDC_PROFILE_URL", "Not set")}')
        self.stdout.write(f'- Issuer: {os.getenv("OIDC_ID_TOKEN_ISSUER", "Not set")}')