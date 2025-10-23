#!/bin/bash

# Test script để gửi lệnh tạo tài khoản từ server Linux
# Chạy script này trên server Linux để gửi lệnh đến máy Windows

# Cấu hình
SERVER_URL="http://103.218.122.188:8000/api/commands"
API_ENDPOINT="http://103.218.122.188:8000/api/commands"

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Remote Lab - Test Create User Command${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Function để gửi lệnh tạo user
send_create_user_command() {
    local username="$1"
    local password="$2"
    
    echo -e "${YELLOW}Đang gửi lệnh tạo user: $username${NC}"
    
    # Tạo JSON payload
    local json_payload=$(cat <<EOF
{
    "action": "create_user",
    "username": "$username",
    "password": "$password"
}
EOF
)
    
    echo -e "${YELLOW}Payload:${NC}"
    echo "$json_payload" | jq .
    echo ""
    
    # Gửi POST request
    local response=$(curl -s -X POST "$API_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        -w "\nHTTP_CODE:%{http_code}")
    
    local http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    local response_body=$(echo "$response" | sed '/HTTP_CODE:/d')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Lệnh đã được gửi thành công!${NC}"
        echo -e "${GREEN}Response:${NC}"
        echo "$response_body" | jq . 2>/dev/null || echo "$response_body"
    else
        echo -e "${RED}❌ Lỗi gửi lệnh (HTTP $http_code)${NC}"
        echo -e "${RED}Response:${NC}"
        echo "$response_body"
    fi
}

# Function để gửi lệnh tạo admin user
send_create_admin_command() {
    local username="$1"
    local password="$2"
    
    echo -e "${YELLOW}Đang gửi lệnh tạo admin user: $username${NC}"
    
    # Tạo JSON payload
    local json_payload=$(cat <<EOF
{
    "action": "create_admin_user",
    "username": "$username",
    "password": "$password"
}
EOF
)
    
    echo -e "${YELLOW}Payload:${NC}"
    echo "$json_payload" | jq .
    echo ""
    
    # Gửi POST request
    local response=$(curl -s -X POST "$API_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        -w "\nHTTP_CODE:%{http_code}")
    
    local http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    local response_body=$(echo "$response" | sed '/HTTP_CODE:/d')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Lệnh admin đã được gửi thành công!${NC}"
        echo -e "${GREEN}Response:${NC}"
        echo "$response_body" | jq . 2>/dev/null || echo "$response_body"
    else
        echo -e "${RED}❌ Lỗi gửi lệnh (HTTP $http_code)${NC}"
        echo -e "${RED}Response:${NC}"
        echo "$response_body"
    fi
}

# Function để kiểm tra trạng thái server
check_server_status() {
    echo -e "${YELLOW}Kiểm tra trạng thái server...${NC}"
    
    local response=$(curl -s -X GET "$API_ENDPOINT" -w "\nHTTP_CODE:%{http_code}")
    local http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d: -f2)
    local response_body=$(echo "$response" | sed '/HTTP_CODE:/d')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✅ Server đang hoạt động${NC}"
        echo -e "${BLUE}Response:${NC}"
        echo "$response_body" | jq . 2>/dev/null || echo "$response_body"
    else
        echo -e "${RED}❌ Server không phản hồi (HTTP $http_code)${NC}"
    fi
    echo ""
}

# Function để hiển thị menu
show_menu() {
    echo -e "${BLUE}Chọn loại lệnh:${NC}"
    echo "1. Tạo user thường"
    echo "2. Tạo admin user"
    echo "3. Kiểm tra trạng thái server"
    echo "4. Test với dữ liệu mẫu"
    echo "5. Thoát"
    echo ""
}

# Function để test với dữ liệu mẫu
test_with_sample_data() {
    echo -e "${YELLOW}Testing với dữ liệu mẫu...${NC}"
    echo ""
    
    # Test 1: Tạo user thường
    echo -e "${BLUE}--- Test 1: Tạo user thường ---${NC}"
    send_create_user_command "testuser" "TestPass123!"
    echo ""
    
    # Test 2: Tạo admin user
    echo -e "${BLUE}--- Test 2: Tạo admin user ---${NC}"
    send_create_admin_command "testadmin" "AdminPass123!"
    echo ""
    
    # Test 3: Kiểm tra trạng thái
    echo -e "${BLUE}--- Test 3: Kiểm tra trạng thái ---${NC}"
    check_server_status
}

# Main execution
main() {
    echo -e "${GREEN}Remote Lab Test Script - Create User Commands${NC}"
    echo ""
    
    # Kiểm tra dependencies
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ curl không được cài đặt. Vui lòng cài đặt curl.${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠️ jq không được cài đặt. JSON output sẽ không được format.${NC}"
        echo -e "${YELLOW}Để cài đặt: sudo apt-get install jq${NC}"
        echo ""
    fi
    
    # Kiểm tra kết nối server
    check_server_status
    
    # Menu loop
    while true; do
        show_menu
        read -p "Nhập lựa chọn (1-5): " choice
        
        case $choice in
            1)
                echo ""
                read -p "Nhập username: " username
                read -s -p "Nhập password: " password
                echo ""
                send_create_user_command "$username" "$password"
                echo ""
                ;;
            2)
                echo ""
                read -p "Nhập admin username: " username
                read -s -p "Nhập admin password: " password
                echo ""
                send_create_admin_command "$username" "$password"
                echo ""
                ;;
            3)
                check_server_status
                ;;
            4)
                test_with_sample_data
                ;;
            5)
                echo -e "${GREEN}Thoát script.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Lựa chọn không hợp lệ. Vui lòng chọn 1-5.${NC}"
                echo ""
                ;;
        esac
    done
}

# Chạy main function
main "$@"
