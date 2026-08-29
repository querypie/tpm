import csv
import requests
import logging
from collections import defaultdict

class ServerProcessor:
    def __init__(self, api_base_url, api_key):
        """
        API를 통해 서버 및 서버 그룹을 처리하는 클래스 초기화

        Args:
            api_base_url (str): API 기본 URL (예: 'https://example.com')
            api_key (str): API 인증에 사용할 키
        """
        self.api_base_url = api_base_url
        self.headers = {
            "Authorization": api_key,
            "Content-Type": "application/json"
        }
        # 로깅 설정
        self.logger = logging.getLogger(__name__)
        # 서버 UUID를 저장할 딕셔너리 (name -> uuid)
        self.server_uuids = {}
        # 서버 그룹 UUID를 저장할 딕셔너리 (name -> uuid)
        self.server_group_uuids = {}
        # Secret Store UUID
        self.secret_store_uuid = None

    def get_secret_store_uuid(self):
        """
        첫 번째 Secret Store의 UUID를 가져옴

        Returns:
            str: Secret Store UUID 또는 None (오류 발생 시)
        """
        if self.secret_store_uuid:
            return self.secret_store_uuid

        url = f"{self.api_base_url}/api/external/v2/security/secret-stores"

        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()

            secret_stores = response.json()
            if secret_stores and len(secret_stores) > 0:
                self.secret_store_uuid = secret_stores[0]["uuid"]
                self.logger.info(f"Secret Store UUID: {self.secret_store_uuid}")
                return self.secret_store_uuid
            else:
                self.logger.error("Secret Store를 찾을 수 없습니다.")
                return None
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Secret Store 조회 중 오류 발생: {e}")
            return None

    def server_exists(self, name):
        """
        서버 존재 여부 확인 및 UUID 반환

        Args:
            name (str): 확인할 서버 이름

        Returns:
            str: 서버 UUID 또는 None (존재하지 않는 경우)
        """
        # 이미 캐시된 경우 바로 반환
        if name in self.server_uuids:
            return self.server_uuids[name]

        url = f"{self.api_base_url}/api/external/v2/sac/servers?name={name}"

        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()

            data = response.json()
            servers = data.get("list", [])

            if servers and len(servers) > 0:
                server_uuid = servers[0]["server"]["uuid"]
                self.server_uuids[name] = server_uuid
                return server_uuid
            return None
        except requests.exceptions.RequestException as e:
            self.logger.error(f"서버 확인 중 오류 발생: {e}")
            return None

    def add_server(self, server_data):
        """
        새 서버 추가

        Args:
            server_data (dict): 서버 정보 (host, name, osType, sshPort 등)

        Returns:
            str: 서버 UUID 또는 None (오류 발생 시)
        """
        url = f"{self.api_base_url}/api/external/v2/sac/servers"

        try:
            response = requests.post(url, headers=self.headers, json=server_data)
            response.raise_for_status()

            result = response.json()
            server_uuid = result.get("uuid")

            if server_uuid:
                self.server_uuids[server_data["name"]] = server_uuid

            return server_uuid
        except requests.exceptions.RequestException as e:
            self.logger.error(f"서버 추가 중 오류 발생: {e}")
            return None

    def add_server_tag(self, server_uuid, key, value):
        """
        서버에 태그 추가

        Args:
            server_uuid (str): 서버 UUID
            key (str): 태그 키
            value (str): 태그 값

        Returns:
            bool: 성공 여부
        """
        url = f"{self.api_base_url}/api/external/v2/sac/servers/{server_uuid}/tags"

        data = {
            "customTags": [
                {
                    "key": key,
                    "value": value
                }
            ],
            "overwrite": True
        }

        try:
            response = requests.post(url, headers=self.headers, json=data)
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            self.logger.error(f"서버 태그 추가 중 오류 발생: {e}")
            return False

    def server_group_exists(self, name):
        """
        서버 그룹 존재 여부 확인 및 UUID 반환

        Args:
            name (str): 확인할 서버 그룹 이름

        Returns:
            str: 서버 그룹 UUID 또는 None (존재하지 않는 경우)
        """
        # 이미 캐시된 경우 바로 반환
        if name in self.server_group_uuids:
            return self.server_group_uuids[name]

        url = f"{self.api_base_url}/api/external/v2/sac/server-groups?name={name}"

        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()

            data = response.json()
            groups = data.get("list", [])

            if groups and len(groups) > 0:
                group_uuid = groups[0]["uuid"]
                self.server_group_uuids[name] = group_uuid
                return group_uuid
            return None
        except requests.exceptions.RequestException as e:
            self.logger.error(f"서버 그룹 확인 중 오류 발생: {e}")
            return None

    def add_server_group(self, name, server_group_tag, description=""):
        """
        새 서버 그룹 추가

        Args:
            name (str): 서버 그룹 이름
            server_group_tag (str): 서버 그룹 태그 값
            description (str, optional): 설명

        Returns:
            str: 서버 그룹 UUID 또는 None (오류 발생 시)
        """
        secret_store_uuid = self.get_secret_store_uuid() or ""

        url = f"{self.api_base_url}/api/external/v2/sac/server-groups"

        data = {
            "name": name,
            "description": description,
            "filterTags": [
                {
                    "key": "server_group",
                    "operator": "=",
                    "value": server_group_tag
                }
            ],
            "secretStoreUuid": secret_store_uuid
        }

        try:
            response = requests.post(url, headers=self.headers, json=data)
            response.raise_for_status()

            result = response.json()
            group_uuid = result.get("uuid")

            if group_uuid:
                self.server_group_uuids[name] = group_uuid

            return group_uuid
        except requests.exceptions.RequestException as e:
            self.logger.error(f"서버 그룹 추가 중 오류 발생: {e}")
            return None

    def add_server_group_account(self, server_group_uuid, account_name):
        """
        서버 그룹에 계정 추가

        Args:
            server_group_uuid (str): 서버 그룹 UUID
            account_name (str): 계정 이름

        Returns:
            str: 계정 UUID 또는 None (오류 발생 시)
        """
        url = f"{self.api_base_url}/api/external/v2/sac/server-groups/{server_group_uuid}/accounts"

        data = {
            "auth": {
                "accountId": account_name,
                "authType": "PASSWORD",
                "password": None,
                "sshKeyUuid": ""
            },
            "accountType": "QUERYPIE"
        }

        try:
            response = requests.post(url, headers=self.headers, json=data)
            response.raise_for_status()

            result = response.json()
            return result.get("uuid")
        except requests.exceptions.RequestException as e:
            self.logger.error(f"서버 그룹 계정 추가 중 오류 발생: {e}")
            return None

def process_server_csv(csv_file_path, api_base_url, api_key):
    """
    CSV 파일을 처리하여 서버, 서버 그룹 및 계정 등록

    Args:
        csv_file_path (str): CSV 파일 경로
        api_base_url (str): API 기본 URL
        api_key (str): API 키

    Returns:
        bool: 성공 여부
    """
    processor = ServerProcessor(api_base_url, api_key)

    # 로깅 설정
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)

    server_success_count = 0
    server_skip_count = 0
    server_error_count = 0

    # 서버 그룹별 계정 이름 매핑
    server_group_accounts = defaultdict(set)

    logger.info(f"CSV 파일 처리 시작: {csv_file_path}")

    # 1단계: CSV 파일을 읽고 서버 생성 및 태그 추가
    try:
        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            csv_reader = csv.DictReader(csvfile)

            for row_num, row in enumerate(csv_reader, start=2):  # 헤더를 제외하고 2부터 시작
                try:
                    # 필요한 필드가 모두 있는지 확인
                    required_fields = ['host', 'name', 'osType', 'sshport', 'server_group', 'account_name']
                    if not all(field in row for field in required_fields):
                        missing = [f for f in required_fields if f not in row]
                        logger.warning(f"행 {row_num}: 필수 필드 누락 - {', '.join(missing)}")
                        server_error_count += 1
                        continue

                    name = row['name']
                    server_group = row['server_group']
                    account_name = row['account_name']

                    # 계정 이름을 서버 그룹별로 수집
                    server_group_accounts[server_group].add(account_name)

                    # 서버가 이미 존재하는지 확인
                    server_uuid = processor.server_exists(name)
                    if server_uuid:
                        logger.info(f"행 {row_num}: 서버 '{name}'가 이미 존재합니다. UUID: {server_uuid}")
                        server_skip_count += 1
                    else:
                        # 서버 추가
                        server_data = {
                            'host': row['host'],
                            'name': name,
                            'osType': row['osType'],
                            'sshPort': int(row['sshport'])
                        }

                        server_uuid = processor.add_server(server_data)
                        if not server_uuid:
                            logger.error(f"행 {row_num}: 서버 '{name}' 추가 실패")
                            server_error_count += 1
                            continue

                        logger.info(f"행 {row_num}: 서버 '{name}' 추가 성공 (UUID: {server_uuid})")
                        server_success_count += 1

                    # 서버에 태그 추가
                    tag_result = processor.add_server_tag(
                        server_uuid,
                        "server_role",
                        server_group
                    )

                    # 서버 그룹 필터를 위한 태그 추가
                    tag_result = processor.add_server_tag(
                        server_uuid,
                        "server_group",
                        server_group
                    )

                    if tag_result:
                        logger.info(f"행 {row_num}: 서버 '{name}' 태그 추가 성공")
                    else:
                        logger.warning(f"행 {row_num}: 서버 '{name}' 태그 추가 실패")

                except Exception as e:
                    logger.error(f"행 {row_num} 처리 중 오류 발생: {e}")
                    server_error_count += 1

        # 2단계: 고유한 서버 그룹을 생성하고 계정 설정
        group_success_count = 0
        group_skip_count = 0
        group_error_count = 0
        account_success_count = 0
        account_error_count = 0

        for server_group, account_names in server_group_accounts.items():
            try:
                # 서버 그룹이 이미 존재하는지 확인
                group_uuid = processor.server_group_exists(server_group)

                if group_uuid:
                    logger.info(f"서버 그룹 '{server_group}'가 이미 존재합니다. UUID: {group_uuid}")
                    group_skip_count += 1
                else:
                    # 서버 그룹 추가
                    group_uuid = processor.add_server_group(
                        server_group,
                        server_group,
                        f"Auto created server group for {server_group}"
                    )

                    if group_uuid:
                        logger.info(f"서버 그룹 '{server_group}' 추가 성공 (UUID: {group_uuid})")
                        group_success_count += 1
                    else:
                        logger.error(f"서버 그룹 '{server_group}' 추가 실패")
                        group_error_count += 1
                        continue

                # 계정 설정
                for account_name in account_names:
                    account_uuid = processor.add_server_group_account(group_uuid, account_name)

                    if account_uuid:
                        logger.info(f"서버 그룹 '{server_group}' 계정 추가 성공 (UUID: {account_uuid})")
                        account_success_count += 1
                    else:
                        logger.error(f"서버 그룹 '{server_group}' 계정 추가 실패")
                        account_error_count += 1

            except Exception as e:
                logger.error(f"서버 그룹 '{server_group}' 처리 중 오류 발생: {e}")
                group_error_count += 1

        logger.info(f"서버 처리 결과: 성공={server_success_count}, 스킵={server_skip_count}, 오류={server_error_count}")
        logger.info(f"서버 그룹 처리 결과: 성공={group_success_count}, 스킵={group_skip_count}, 오류={group_error_count}")
        logger.info(f"계정 처리 결과: 성공={account_success_count}, 오류={account_error_count}")

        return True

    except Exception as e:
        logger.error(f"CSV 파일 처리 중 오류 발생: {e}")
        return False
