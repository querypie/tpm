import csv
import requests
import logging
import datetime
from collections import defaultdict

class RoleAssigner:
    def __init__(self, api_base_url, api_key):
        """
        API를 통해 사용자에게 역할을 할당하는 클래스 초기화
        
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
        # 사용자 UUID를 저장할 딕셔너리 (loginId -> uuid)
        self.user_uuids = {}
        # 역할 UUID를 저장할 딕셔너리 (roleName -> uuid)
        self.role_uuids = {}
        # 사용자에게 할당된 역할을 저장할 딕셔너리 (user_uuid -> {role_uuid})
        self.assigned_roles = defaultdict(set)
    
    def find_user(self, login_id):
        """
        사용자 찾기
        
        Args:
            login_id (str): 사용자 로그인 ID
            
        Returns:
            str: 사용자 UUID 또는 None (존재하지 않는 경우)
        """
        # 이미 캐시된 경우 바로 반환
        if login_id in self.user_uuids:
            return self.user_uuids[login_id]
            
        url = f"{self.api_base_url}/api/external/v2/users?loginId={login_id}"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            
            data = response.json()
            users = data.get("list", [])
            
            if users and len(users) > 0:
                user = users[0]
                if user.get("loginId") == login_id:
                    user_uuid = user.get("uuid")
                    self.user_uuids[login_id] = user_uuid
                    return user_uuid
            return None
        except requests.exceptions.RequestException as e:
            self.logger.error(f"사용자 검색 중 오류 발생: {e}")
            return None
    
    def find_role(self, role_name):
        """
        역할 찾기
        
        Args:
            role_name (str): 역할 이름
            
        Returns:
            str: 역할 UUID 또는 None (존재하지 않는 경우)
        """
        # 이미 캐시된 경우 바로 반환
        if role_name in self.role_uuids:
            return self.role_uuids[role_name]
            
        url = f"{self.api_base_url}/api/external/v2/sac/roles?name={role_name}"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            
            data = response.json()
            roles = data.get("list", [])
            
            for role in roles:
                if role.get("name") == role_name:
                    role_uuid = role.get("uuid")
                    self.role_uuids[role_name] = role_uuid
                    return role_uuid
            return None
        except requests.exceptions.RequestException as e:
            self.logger.error(f"역할 검색 중 오류 발생: {e}")
            return None
    
    def get_user_roles(self, user_uuid):
        """
        사용자에게 할당된 역할 목록 가져오기
        
        Args:
            user_uuid (str): 사용자 UUID
            
        Returns:
            set: 역할 UUID 집합
        """
        # 이미 캐시된 경우 바로 반환
        if user_uuid in self.assigned_roles:
            return self.assigned_roles[user_uuid]
            
        url = f"{self.api_base_url}/api/external/v2/sac/access-controls/{user_uuid}/roles"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            
            data = response.json()
            roles = data.get("list", [])
            
            role_uuids = set()
            for role in roles:
                role_uuid = role.get("serverRoleUuid")
                role_uuids.add(role_uuid)
            
            self.assigned_roles[user_uuid] = role_uuids
            return role_uuids
        except requests.exceptions.RequestException as e:
            self.logger.error(f"사용자 역할 목록 조회 중 오류 발생: {e}")
            return set()
    
    def assign_role(self, user_uuid, role_uuid, expiry_years=10):
        """
        사용자에게 역할 할당
        
        Args:
            user_uuid (str): 사용자 UUID
            role_uuid (str): 역할 UUID
            expiry_years (int, optional): 만료 기간(년). 기본값은 10
            
        Returns:
            bool: 성공 여부
        """
        url = f"{self.api_base_url}/api/external/v2/sac/access-controls/{user_uuid}/roles"
        
        # 10년 후 날짜 계산
        today = datetime.date.today()
        expiry_date = today.replace(year=today.year + expiry_years)
        expiry_str = expiry_date.isoformat()
        
        data = {
            "expiryAt": expiry_str,
            "serverRoleUuids": [role_uuid]
        }
        
        try:
            response = requests.post(url, headers=self.headers, json=data)
            response.raise_for_status()
            
            # 할당 성공 시 캐시 업데이트
            if user_uuid in self.assigned_roles:
                self.assigned_roles[user_uuid].add(role_uuid)
            else:
                self.assigned_roles[user_uuid] = {role_uuid}
                
            return True
        except requests.exceptions.RequestException as e:
            self.logger.error(f"역할 할당 중 오류 발생: {e}")
            return False

def process_role_assignment(csv_file_path, api_base_url, api_key):
    """
    CSV 파일을 처리하여 사용자에게 역할 할당
    
    Args:
        csv_file_path (str): CSV 파일 경로
        api_base_url (str): API 기본 URL
        api_key (str): API 키
        
    Returns:
        bool: 성공 여부
    """
    assigner = RoleAssigner(api_base_url, api_key)
    
    # 로깅 설정
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)
    
    success_count = 0
    skip_count = 0
    error_count = 0
    
    logger.info(f"CSV 파일 처리 시작: {csv_file_path}")
    
    try:
        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            csv_reader = csv.DictReader(csvfile)
            
            for row_num, row in enumerate(csv_reader, start=2):  # 헤더를 제외하고 2부터 시작
                try:
                    # 필요한 필드가 모두 있는지 확인
                    required_fields = ['loginId', 'role']
                    if not all(field in row for field in required_fields):
                        missing = [f for f in required_fields if f not in row]
                        logger.warning(f"행 {row_num}: 필수 필드 누락 - {', '.join(missing)}")
                        error_count += 1
                        continue
                    
                    login_id = row['loginId']
                    role_values = row['role'].split(';')
                    
                    # 역할 값이 비어있으면 건너뛰기
                    if not any(role_value.strip() for role_value in role_values):
                        logger.warning(f"행 {row_num}: 역할 값이 비어 있습니다. 건너뜁니다.")
                        skip_count += 1
                        continue
                    
                    # 사용자 찾기
                    user_uuid = assigner.find_user(login_id)
                    if not user_uuid:
                        logger.error(f"행 {row_num}: 사용자 '{login_id}'를 찾을 수 없습니다.")
                        error_count += 1
                        continue
                    
                    # 사용자에게 이미 할당된 역할 가져오기
                    existing_roles = assigner.get_user_roles(user_uuid)
                    
                    role_success = 0
                    role_skip = 0
                    role_error = 0
                    
                    # 각 역할에 대해 처리
                    for role_value in role_values:
                        role_value = role_value.strip()
                        if not role_value:
                            continue
                            
                        role_name = f"{role_value} role"
                        
                        # 역할 찾기
                        role_uuid = assigner.find_role(role_name)
                        if not role_uuid:
                            logger.error(f"행 {row_num}: 역할 '{role_name}'을 찾을 수 없습니다.")
                            role_error += 1
                            continue
                        
                        # 이미 할당된 역할인지 확인
                        if role_uuid in existing_roles:
                            logger.info(f"행 {row_num}: 사용자 '{login_id}'에게 이미 역할 '{role_name}'이 할당되어 있습니다.")
                            role_skip += 1
                            continue
                        
                        # 역할 할당
                        result = assigner.assign_role(user_uuid, role_uuid)
                        if result:
                            logger.info(f"행 {row_num}: 사용자 '{login_id}'에게 역할 '{role_name}' 할당 성공")
                            role_success += 1
                        else:
                            logger.error(f"행 {row_num}: 사용자 '{login_id}'에게 역할 '{role_name}' 할당 실패")
                            role_error += 1
                    
                    # 행 처리 결과 집계
                    if role_success > 0:
                        success_count += 1
                    elif role_skip > 0:
                        skip_count += 1
                    else:
                        error_count += 1
                        
                    logger.info(f"행 {row_num}: 처리 완료 (성공: {role_success}, 스킵: {role_skip}, 오류: {role_error})")
                        
                except Exception as e:
                    logger.error(f"행 {row_num} 처리 중 오류 발생: {e}")
                    error_count += 1
    
    except Exception as e:
        logger.error(f"CSV 파일 처리 중 오류 발생: {e}")
        return False
    
    logger.info(f"CSV 파일 처리 완료: 성공={success_count}, 스킵={skip_count}, 오류={error_count}")
    return True 