## 버전별 설명
### Version 2
- 작업 계획(순서대로)
    1. User input 처리(json)
    2. RDS 추가
    3. s3 추가
    4. 로드밸런서 추가
- 작업 내역
    - 인스턴스 여러개 가용 영역별 subnet 마다 생성되는 것 확인
        - **현재 public subnet에 생성되는걸로 테스트**
---
### Version 1
- 유저 입력에 따른 기본적인 VPC와 네트워크 설정
    - VPC 생성
    - 모든 가용영역에 private/public 서브넷 생성
        - db 전용 서브넷은 생성하지 않았음
    - private/public 라우팅 테이블 서브넷에 추가
- 유저의 인스턴스와 AMI
    - 유저의 github repo에 따른 AMI 자동 구성
    - 인스턴스 갯수 입력값에 따른 인스턴스 자동 생성
        - 서브넷 지정하는 부분 약간의 수정 필요
    - 인스턴스 보안그룹 생성
        - SSH, ICMP, HTTP, HTTPs 허용
---