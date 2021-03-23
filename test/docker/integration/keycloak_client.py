import requests

class KeycloakClient:
    def __init__(self, url, realm, username, password):
        self._endpoint = url
        self._realm = realm
        self._session  = requests.session()
        self._username = username
        self._password = password

    def discover(self, config_type = "openid-configuration"):
        res = self._session.get("{}/auth/realms/{}/.well-known/{}".format(self._endpoint, self._realm, config_type))
        res.raise_for_status()
        return res.json()

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
            "Authorization": f'Bearer {self.get_token("admin-cli")}'
        }

    def get_token(self, client_id):
        url = "{}/auth/realms/{}/protocol/openid-connect/token".format(self._endpoint, self._realm)
        
        payload = f'client_id={client_id}&grant_type=password' + \
                  f'&username={self._username}&password={self._password}'

        headers = {
            "Content-Type": "application/x-www-form-urlencoded"
        }
        
        res = self._session.post(url, data=payload, headers=headers)
        res.raise_for_status()
        
        return res.json()["access_token"]
