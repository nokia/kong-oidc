#!/usr/bin/env python3

import os
from collections import namedtuple

import requests


Config = namedtuple("Config", [
    "keycloak_endpoint",
    "keycloak_admin",
    "keycloak_password",
    "client_id",
    "client_secret",
    "discovery",
])


def get_config():
    return Config(
        keycloak_endpoint = os.getenv("KC_ENDPOINT", "http://keycloak:8080"),
        keycloak_admin = os.getenv("KC_ADMIN", "admin"),
        keycloak_password = os.getenv("KC_PASSWORD", "password"),
        client_id = os.getenv("CLIENT_ID", "kong"),
        client_secret = os.getenv("CLIENT_SECRET"),
        discovery = os.getenv("KC_ENDPOINT", "http://keycloak:8080") + \
            "/auth/realms/master/.well-known/openid-configuration",
    )


class KeycloakClient:
    def __init__(self):
        self._endpoint = "http://localhost:8080"
        self._session = requests.session()

    def create_client(self, name, secret):
        config = get_config()
        url = "{}/auth/admin/realms/master/clients".format(
            config.keycloak_endpoint)
        payload = {
            "clientId": name,
            "secret": secret,
            "redirectUris": ["*"],
        }

        headers = self.get_auth_header()
        res = self._session.post(url, json=payload, headers=headers)
        if res.status_code not in [201, 409]:
            raise Exception("Cannot create client")

    def get_auth_header(self):
        return {
            "Authorization": "Bearer {}".format(self.get_admin_token())
        }

    def get_admin_token(self):
        config = get_config()
        url = "{}/auth/realms/master/protocol/openid-connect/token".format(
            config.keycloak_endpoint)
        payload = "client_id=admin-cli&grant_type=password" + \
            "&username={}&password={}".format(config.keycloak_admin,
                                             config.keycloak_password
                                             )
        headers = {
            "Content-Type": "application/x-www-form-urlencoded"
        }
        res = self._session.post(url, data=payload, headers=headers)
        res.raise_for_status()
        return res.json()["access_token"]


class KongClient:
    def __init__(self):
        self._endpoint = "http://localhost:8001"
        self._session = requests.session()

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


config = get_config()

kc_client = KeycloakClient()
kc_client.create_client(config.client_id, config.client_secret)

kong_client = KongClient()
kong_client.delete_service("httpbin")
kong_client.create_service("httpbin", "http://httpbin.org")
kong_client.create_route("httpbin", ["/httpbin"])
kong_client.create_plugin("oidc", "httpbin", {
    "client_id": config.client_id,
    "client_secret": config.client_secret,
    "discovery": config.discovery,
    "logout_path": "/httpbin/logout",
})

