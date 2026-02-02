#!/usr/bin/env python3
"""
CSV 파일에서 사용자 정보를 읽고 API를 통해 사용자를 등록하는 프로그램
"""

import os
import sys
import argparse
import logging
from user_processor import process_users_csv

def main():
    # 로깅 설정
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    logger = logging.getLogger(__name__)
    
    # 명령행 인자 파싱
    parser = argparse.ArgumentParser(description='CSV 파일에서 사용자 정보를 읽고 API를 통해 사용자를 등록합니다.')
    parser.add_argument('csv_file', help='처리할 CSV 파일 경로')
    parser.add_argument('--api-url', dest='api_url', default=os.environ.get('API_BASE_URL'), 
                        help='API 기본 URL (기본값: 환경 변수 API_BASE_URL)')
    parser.add_argument('--api-key', dest='api_key', default=os.environ.get('API_KEY'),
                        help='API 인증 키 (기본값: 환경 변수 API_KEY)')
    
    args = parser.parse_args()
    
    # 필수 매개변수 확인
    if not args.csv_file:
        logger.error("CSV 파일 경로가 필요합니다.")
        parser.print_help()
        return 1
    
    if not args.api_url:
        logger.error("API 기본 URL이 필요합니다. --api-url 옵션을 사용하거나 API_BASE_URL 환경 변수를 설정하세요.")
        parser.print_help()
        return 1
    
    if not args.api_key:
        logger.error("API 키가 필요합니다. --api-key 옵션을 사용하거나 API_KEY 환경 변수를 설정하세요.")
        parser.print_help()
        return 1
    
    # CSV 파일 존재 확인
    if not os.path.isfile(args.csv_file):
        logger.error(f"CSV 파일을 찾을 수 없습니다: {args.csv_file}")
        return 1
    
    logger.info(f"API URL: {args.api_url}")
    logger.info(f"CSV 파일: {args.csv_file}")
    
    # CSV 처리 시작
    success = process_users_csv(args.csv_file, args.api_url, args.api_key)
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main()) 