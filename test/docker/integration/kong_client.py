import requests

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
