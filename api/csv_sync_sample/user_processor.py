import csv
import requests
import logging

class UserProcessor:
    def __init__(self, api_base_url, api_key):
        """
        API를 통해 사용자를 처리하는 클래스 초기화
        
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
    
    def user_exists(self, login_id):
        """
        사용자 존재 여부 확인
        
        Args:
            login_id (str): 확인할 사용자 ID
            
        Returns:
            bool: 사용자 존재 여부
        """
        url = f"{self.api_base_url}/api/external/v2/users?loginId={login_id}"
        
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            
            data = response.json()
            user_list = data.get("list", [])
            
            # loginId가 정확히 일치하는 사용자 찾기
            for user in user_list:
                if user.get("loginId") == login_id:
                    return True
            return False
            
        except requests.exceptions.RequestException as e:
            self.logger.error(f"사용자 확인 중 오류 발생: {e}")
            return False
    def add_user(self, user_data):
        """
        새 사용자 추가
        
        Args:
            user_data (dict): 사용자 정보 (email, loginId, name, password)
            
        Returns:
            dict: 응답 데이터 또는 None (오류 발생 시)
        """
        url = f"{self.api_base_url}/api/external/v2/users"
        
        try:
            response = requests.post(url, headers=self.headers, json=user_data)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            self.logger.error(f"사용자 추가 중 오류 발생: {e}")
            return None

def process_users_csv(csv_file_path, api_base_url, api_key):
    """
    CSV 파일을 처리하여 사용자 등록
    
    Args:
        csv_file_path (str): CSV 파일 경로
        api_base_url (str): API 기본 URL
        api_key (str): API 키
    """
    processor = UserProcessor(api_base_url, api_key)
    
    # 로깅 설정
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)
    
    success_count = 0
    error_count = 0
    skip_count = 0
    
    logger.info(f"CSV 파일 처리 시작: {csv_file_path}")
    
    try:
        with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
            csv_reader = csv.DictReader(csvfile)
            
            for row_num, row in enumerate(csv_reader, start=2):  # 헤더를 제외하고 2부터 시작
                try:
                    # 필요한 필드가 모두 있는지 확인
                    required_fields = ['email', 'loginId', 'name', 'password']
                    if not all(field in row for field in required_fields):
                        missing = [f for f in required_fields if f not in row]
                        logger.warning(f"행 {row_num}: 필수 필드 누락 - {', '.join(missing)}")
                        error_count += 1
                        continue
                    
                    login_id = row['loginId']
                    
                    # 사용자가 이미 존재하는지 확인
                    if processor.user_exists(login_id):
                        logger.warning(f"행 {row_num}: 사용자 '{login_id}'가 이미 존재합니다. 건너뜁니다.")
                        skip_count += 1
                        continue
                    
                    # 사용자 추가
                    user_data = {
                        'email': row['email'],
                        'loginId': login_id,
                        'name': row['name'],
                        'password': row['password']
                    }
                    
                    # role 필드가 있으면 추가
                    if 'role' in row and row['role']:
                        # 세미콜론으로 구분된 역할들을 리스트로 변환
                        if ';' in row['role']:
                            roles = [role.strip() for role in row['role'].split(';')]
                            logger.info(f"행 {row_num}: {len(roles)}개의 역할이 지정되었습니다: {roles}")
                            user_data['role'] = roles
                        else:
                            user_data['role'] = [row['role']]
                    
                    result = processor.add_user(user_data)
                    if result:
                        logger.info(f"행 {row_num}: 사용자 '{login_id}' 추가 성공 (UUID: {result.get('uuid', 'N/A')})")
                        success_count += 1
                    else:
                        logger.error(f"행 {row_num}: 사용자 '{login_id}' 추가 실패")
                        error_count += 1
                        
                except Exception as e:
                    logger.error(f"행 {row_num} 처리 중 오류 발생: {e}")
                    error_count += 1
    
    except Exception as e:
        logger.error(f"CSV 파일 처리 중 오류 발생: {e}")
        return False
    
    logger.info(f"CSV 파일 처리 완료: 성공={success_count}, 스킵={skip_count}, 오류={error_count}")
    return True 