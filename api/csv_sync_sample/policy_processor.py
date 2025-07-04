import csv
import requests
import logging
import yaml
import json
from collections import defaultdict

class PolicyProcessor:
    def __init__(self, api_base_url, api_key):
        """
        API를 통해 정책 및 역할을 처리하는 클래스 초기화
        
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
        # 정책 UUID를 저장할 딕셔너리 (name -> uuid)
        self.policy_uuids = {}
        # 역할 UUID를 저장할 딕셔너리 (name -> uuid)
        self.role_uuids = {}
    
    def policy_exists(self, policy_name):
        """
        정책 존재 여부 확인 및 UUID 반환
        
        Args:
            policy_name (str): 확인할 정책 이름
            
        Returns:
            str: 정책 UUID 또는 None (존재하지 않는 경우)
        """
        # 이미 캐시된 경우 바로 반환
        if policy_name in self.policy_uuids:
            return self.policy_uuids[policy_name]
            
        url = f"{self.api_base_url}/api/external/v2/sac/policies?name={policy_name}"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            
            data = response.json()
            policies = data.get("list", [])
            
            if policies and len(policies) > 0:
                policy_uuid = policies[0]["uuid"]
                self.policy_uuids[policy_name] = policy_uuid
                return policy_uuid
            return None
        except requests.exceptions.RequestException as e:
            self.logger.error(f"정책 확인 중 오류 발생: {e}")
            return None
    
    def add_policy(self, policy_name, description):
        """
        새 정책 추가
        
        Args:
            policy_name (str): 정책 이름
            description (str): 정책 설명
            
        Returns:
            str: 정책 UUID 또는 None (오류 발생 시)
        """
        url = f"{self.api_base_url}/api/external/v2/sac/policies"
        
        data = {
            "name": policy_name,
            "description": description
        }
        
        try:
            response = requests.post(url, headers=self.headers, json=data)
            response.raise_for_status()
            
            result = response.json()
            policy_uuid = result.get("uuid")
            
            if policy_uuid:
                self.policy_uuids[policy_name] = policy_uuid
            
            return policy_uuid
        except requests.exceptions.RequestException as e:
            self.logger.error(f"정책 추가 중 오류 발생: {e}")
            return None
    
    def update_policy_content(self, policy_uuid, server_group, account_names, justification="initial"):
        """
        정책 내용 업데이트
        
        Args:
            policy_uuid (str): 정책 UUID
            server_group (str): 서버 그룹 이름
            account_names (list): 계정 이름 목록
            justification (str, optional): 변경 사유. 기본값은 "initial"
            
        Returns:
            bool: 성공 여부
        """
        url = f"{self.api_base_url}/api/external/v2/sac/policies/{policy_uuid}/content"
        
        # 계정이 1개인 경우와 여러 개인 경우 처리
        if len(account_names) == 1:
            account = account_names[0]
        else:
            account = account_names
        
        # 정책 내용 생성 (YAML 형식)
        policy_content = {
            "apiVersion": "server.rbac.querypie.com/v1",
            "kind": "SacPolicy",
            "spec": {
                "allow": {
                    "resources": [
                        {
                            "serverGroup": server_group,
                            "account": account
                        }
                    ],
                    "actions": {
                        "protocols": ["ssh", "sftp"],
                        "commandsRef": "Default Policy"
                    },
                    "conditions": {
                        "accessTime": "00:00-23:59",
                        "accessWeekday": ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"],
                        "ipAddresses": ["0.0.0.0/0"]
                    },
                    "options": {
                        "commandAudit": True,
                        "commandDetection": False,
                        "useProxy": True,
                        "maxSessions": 5,
                        "sessionTimeout": 10
                    }
                }
            }
        }
        
        # YAML로 변환
        policy_yaml = yaml.dump(policy_content, default_flow_style=False)
        
        data = {
            "content": policy_yaml,
            "justification": justification
        }
        
        try:
            response = requests.put(url, headers=self.headers, json=data)
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            self.logger.error(f"정책 내용 업데이트 중 오류 발생: {e}")
            return False
    
    def role_exists(self, role_name):
        """
        역할 존재 여부 확인 및 UUID 반환
        
        Args:
            role_name (str): 확인할 역할 이름
            
        Returns:
            str: 역할 UUID 또는 None (존재하지 않는 경우)
        """
        # 이미 캐시된 경우 바로 반환
        if role_name in self.role_uuids:
            return self.role_uuids[role_name]
            
        url = f"{self.api_base_url}/api/external/v2/sac/roles"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            
            data = response.json()
            roles = data.get("list", [])
            
            for role in roles:
                if role.get("name") == role_name:
                    role_uuid = role["uuid"]
                    self.role_uuids[role_name] = role_uuid
                    return role_uuid
            return None
        except requests.exceptions.RequestException as e:
            self.logger.error(f"역할 확인 중 오류 발생: {e}")
            return None
    
    def add_role(self, role_name, description):
        """
        새 역할 추가
        
        Args:
            role_name (str): 역할 이름
            description (str): 역할 설명
            
        Returns:
            str: 역할 UUID 또는 None (오류 발생 시)
        """
        url = f"{self.api_base_url}/api/external/v2/sac/roles"
        
        data = {
            "name": role_name,
            "description": description
        }
        
        try:
            response = requests.post(url, headers=self.headers, json=data)
            response.raise_for_status()
            
            result = response.json()
            role_uuid = result.get("uuid")
            
            if role_uuid:
                self.role_uuids[role_name] = role_uuid
            
            return role_uuid
        except requests.exceptions.RequestException as e:
            self.logger.error(f"역할 추가 중 오류 발생: {e}")
            return None
    
    def add_policies_to_role(self, role_uuid, policy_uuids):
        """
        역할에 정책 추가
        
        Args:
            role_uuid (str): 역할 UUID
            policy_uuids (list): 정책 UUID 목록
            
        Returns:
            bool: 성공 여부
        """
        url = f"{self.api_base_url}/api/external/v2/sac/roles/{role_uuid}/policies"
        
        data = {
            "serverPolicyIdentifiers": policy_uuids
        }
        
        try:
            response = requests.post(url, headers=self.headers, json=data)
            response.raise_for_status()
            return True
        except requests.exceptions.RequestException as e:
            self.logger.error(f"역할에 정책 추가 중 오류 발생: {e}")
            return False

def process_policies_from_csv(csv_file_path, api_base_url, api_key):
    """
    CSV 파일을 처리하여 정책 및 역할 생성
    
    Args:
        csv_file_path (str): CSV 파일 경로
        api_base_url (str): API 기본 URL
        api_key (str): API 키
        
    Returns:
        bool: 성공 여부
    """
    processor = PolicyProcessor(api_base_url, api_key)
    
    # 로깅 설정
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)
    
    # 서버 그룹별 계정 이름 매핑
    server_group_accounts = defaultdict(set)
    
    logger.info(f"CSV 파일 처리 시작: {csv_file_path}")
    
    # 1단계: CSV 파일을 읽고 서버 그룹별 계정 목록 수집
    try:
        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            csv_reader = csv.DictReader(csvfile)
            
            for row_num, row in enumerate(csv_reader, start=2):  # 헤더를 제외하고 2부터 시작
                try:
                    # 필요한 필드가 모두 있는지 확인
                    required_fields = ['server_group', 'account_name']
                    if not all(field in row for field in required_fields):
                        missing = [f for f in required_fields if f not in row]
                        logger.warning(f"행 {row_num}: 필수 필드 누락 - {', '.join(missing)}")
                        continue
                    
                    server_group = row['server_group']
                    account_name = row['account_name']
                    
                    # 계정 이름을 서버 그룹별로 수집
                    server_group_accounts[server_group].add(account_name)
                        
                except Exception as e:
                    logger.error(f"행 {row_num} 처리 중 오류 발생: {e}")
        
        # 2단계: 각 서버 그룹에 대한 정책 및 역할 생성
        policy_success_count = 0
        policy_skip_count = 0
        policy_error_count = 0
        role_success_count = 0
        role_skip_count = 0
        role_error_count = 0
        
        for server_group, account_names in server_group_accounts.items():
            try:
                # 정책 이름 및 설명 설정
                policy_name = f"{server_group} policy"
                policy_description = server_group
                
                # 정책이 이미 존재하는지 확인
                policy_uuid = processor.policy_exists(policy_name)
                
                if policy_uuid:
                    logger.info(f"정책 '{policy_name}'이(가) 이미 존재합니다. UUID: {policy_uuid}")
                    policy_skip_count += 1
                else:
                    # 정책 추가
                    policy_uuid = processor.add_policy(policy_name, policy_description)
                    
                    if not policy_uuid:
                        logger.error(f"정책 '{policy_name}' 추가 실패")
                        policy_error_count += 1
                        continue
                        
                    logger.info(f"정책 '{policy_name}' 추가 성공 (UUID: {policy_uuid})")
                    policy_success_count += 1
                
                # 정책 내용 업데이트
                account_list = list(account_names)
                update_result = processor.update_policy_content(policy_uuid, server_group, account_list)
                
                if update_result:
                    logger.info(f"정책 '{policy_name}' 내용 업데이트 성공")
                else:
                    logger.error(f"정책 '{policy_name}' 내용 업데이트 실패")
                
                # 역할 이름 및 설명 설정
                role_name = f"{server_group} role"
                role_description = server_group
                
                # 역할이 이미 존재하는지 확인
                role_uuid = processor.role_exists(role_name)
                
                if role_uuid:
                    logger.info(f"역할 '{role_name}'이(가) 이미 존재합니다. UUID: {role_uuid}")
                    role_skip_count += 1
                else:
                    # 역할 추가
                    role_uuid = processor.add_role(role_name, role_description)
                    
                    if not role_uuid:
                        logger.error(f"역할 '{role_name}' 추가 실패")
                        role_error_count += 1
                        continue
                        
                    logger.info(f"역할 '{role_name}' 추가 성공 (UUID: {role_uuid})")
                    role_success_count += 1
                
                # 역할에 정책 추가
                policies_result = processor.add_policies_to_role(role_uuid, [policy_uuid])
                
                if policies_result:
                    logger.info(f"역할 '{role_name}'에 정책 추가 성공")
                else:
                    logger.error(f"역할 '{role_name}'에 정책 추가 실패")
                    
            except Exception as e:
                logger.error(f"서버 그룹 '{server_group}' 처리 중 오류 발생: {e}")
                policy_error_count += 1
                role_error_count += 1
        
        logger.info(f"정책 처리 결과: 성공={policy_success_count}, 스킵={policy_skip_count}, 오류={policy_error_count}")
        logger.info(f"역할 처리 결과: 성공={role_success_count}, 스킵={role_skip_count}, 오류={role_error_count}")
        
        return True
        
    except Exception as e:
        logger.error(f"CSV 파일 처리 중 오류 발생: {e}")
        return False 