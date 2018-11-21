#!/usr/bin/env python3

import os
import requests

from collections import namedtuple

local_ip      = os.getenv("IP", default="")
host          = "localhost"
env_file_path = ".env"

Config = namedtuple("Config", [
    "keycloak_endpoint",
    "keycloak_admin",
    "keycloak_password",
    "client_id",
    "client_secret",
    "discovery",
    "kong_endpoint"
])

def validate_ip_set():
    if local_ip == "":
        raise Exception("IP environment variable not set. See README.md for further instructions.")

"""
Attempt to pull in environment variables from .env file
Returns {"KONG_TAG": "", "KONG_DB_TAG": ":10.1" ...}
"""
def get_env_vars():
    with open(env_file_path) as f:
        lines = [l.rstrip().split("=", maxsplit=1) 
                 for l in f 
                 # Skip blank lines and comments
                 if l.strip() != "" and not l.startswith("#")]

    return {l[0]: l[1] for l in lines}

def get_config(env):
    keycloak_url   = "http://{}:{}".format(host, env["KEYCLOAK_PORT"])
    discovery_path = "/auth/realms/master/.well-known/openid-configuration"

    return Config(
        keycloak_endpoint = keycloak_url,
        keycloak_admin    = env["KEYCLOAK_USER"],
        keycloak_password = env["KEYCLOAK_PW"],
        client_id         = "kong",
        client_secret     = "secret",
        # Set host to local IP address so requests from Kong to Keycloak can make it
        # out of the container
        discovery         = "http://{}:{}{}".format(local_ip, env["KEYCLOAK_PORT"], discovery_path),
        kong_endpoint     = "http://{}:{}".format(host, env["KONG_HTTP_ADMIN_PORT"])
    )


class KeycloakClient:
    def __init__(self, url, username, password):
        self._endpoint = url
        self._session  = requests.session()
        self._username = username
        self._password = password

    def create_client(self, name, secret):
        url     = "{}/auth/admin/realms/master/clients".format(self._endpoint)
        payload = {
            "clientId": name,
            "secret": secret,
            "redirectUris": ["*"],
        }

        headers = self.get_auth_header()
        res     = self._session.post(url, json=payload, headers=headers)
        
        if res.status_code not in [201, 409]:
            raise Exception("Cannot Keycloak create client")

    def get_auth_header(self):
        return {
            "Authorization": "Bearer {}".format(self.get_admin_token())
        }

    def get_admin_token(self):
        url     = "{}/auth/realms/master/protocol/openid-connect/token".format(self._endpoint)
        
        payload = "client_id=admin-cli&grant_type=password" + \
            "&username={}&password={}".format(self._username, self._password)
        
        headers = {
            "Content-Type": "application/x-www-form-urlencoded"
        }
        
        res = self._session.post(url, data=payload, headers=headers)
        res.raise_for_status()
        
        return res.json()["access_token"]


class KongClient:
    def __init__(self, url):
        self._endpoint = url
        self._session  = requests.session()

    def create_service(self, name, upstream_url):
        url = "{}/services".format(self._endpoint)
        payload = {
            "name": name,
            "url": upstream_url,
        }
        res = self._session.post(url, json=payload)
        res.raise_for_status()
        return res.json()

    def create_route(self, service_name, paths):
        url = "{}/services/{}/routes".format(self._endpoint, service_name)
        payload = {
            "paths": paths,
        }
        res = self._session.post(url, json=payload)
        res.raise_for_status()
        return res.json()

    def create_plugin(self, plugin_name, service_name, config):
        url = "{}/services/{}/plugins".format(self._endpoint, service_name)
        payload = {
            "name": plugin_name,
            "config": config,
        }
        res = self._session.post(url, json=payload)
        try:
            res.raise_for_status()
        except Exception as e:
            print(res.text)
            raise e
        return res.json()

    def delete_service(self, name):
        try:
            routes = self.get_routes(name)
            for route in routes:
                self.delete_route(route)
        except requests.exceptions.HTTPError:
            pass
        url = "{}/services/{}".format(self._endpoint, name)
        self._session.delete(url).raise_for_status()

    def delete_route(self, route_id):
        url = "{}/routes/{}".format(self._endpoint, route_id)
        self._session.delete(url).raise_for_status()

    def get_routes(self, service_name):
        url = "{}/services/{}/routes".format(self._endpoint, service_name)
        res = self._session.get(url)
        res.raise_for_status()
        return map(lambda x: x['id'], res.json()['data'])

if __name__ == '__main__':
    validate_ip_set()

    print("Reading environment vars from {}".format(env_file_path))
    env    = get_env_vars()
    config = get_config(env)

    print("Creating Keycloak HTTP Client at {}".format(config.keycloak_endpoint))
    kc_client = KeycloakClient(config.keycloak_endpoint,
                               config.keycloak_admin,
                               config.keycloak_password)

    print("Creating Keycloak client: {}".format(config.client_id))
    kc_client.create_client(config.client_id, config.client_secret)

    print("Creating Kong HTTP Admin Client at {}".format(config.kong_endpoint))
    kong_client = KongClient(config.kong_endpoint)

    print("Configuring Kong services, routes, and plugins for testing")
    kong_client.delete_service("httpbin")
    kong_client.create_service("httpbin", "http://httpbin.org")
    kong_client.create_route("httpbin", ["/httpbin"])
    kong_client.create_plugin("oidc", "httpbin", {
        "client_id":     config.client_id,
        "client_secret": config.client_secret,
        "discovery":     config.discovery,
        "logout_path":   "/httpbin/logout",
    })

    print("Environment setup complete")