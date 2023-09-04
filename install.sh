#!/usr/bin/env bash

# curl -O https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/install.sh
# chmod +x install.sh
# ./install.sh www.mydomain.net username@gmail.com

# exit when any command fails or any unbound variable is accessed
set -eu -o pipefail

# check if parameter is empty
# (( )) 是算術擴展
if (( "$#" < 2 ));
  then
    echo "syntax: install.sh <FQDN> <email-for-certbot>"
    echo "example: install.sh www.mydoamin.net username@gmail.com"
    exit 1
fi

# 將傳入 shell script 的參數賦值給變數。用 $1、$2 接輸入參數，如 fqdn = $1
# 也可用 if [[ -z $fqdn || -z $email ]]; 檢查參數是否空白
# [[ ... ]] 是擴展的條件測試語法。-z 運算符測試變量是否為空。
fqdn="$1"
email="$2"

# Bash 的 IF 分支： if then .. fi
# if os is not ubuntu or debian, exit，用 grep -q "Ubuntu" /etc/issue 偵測 OS 為 Ubuntu/Debian
if ! grep -q "Ubuntu" /etc/issue && ! grep -q "Debian" /etc/issue;
  then
    echo "This script only works on Ubuntu or Debian"
    exit 1
fi

# get administrative privilege
# invoke `sudo' only when running as an unprivileged user (nonzero "$UID")
# 檢查腳本的執行權限，如果需要執行權限，則使用 sudo 命令獲取權限。
declare -a a_privilege=()
# 檢查 $UID 是否為非零值，如果是，則執行 then 子句中的命令。$UID 是用來表示當前用戶的身份識別碼 (UID)。
# 如果 $UID 變量等於 0，表示當前用戶是 root 用戶，已經具有足夠權限，不需要用 sudo 命令獲取權限；否則，將 "sudo" 字符串添加到 a_privilege 數組中，然後使用 "${a_privilege[@]}" 命令獲取權限，這個命令會提示用戶輸入密碼以獲取權限。
if (( "$UID" ));
  then
    a_privilege+=( "sudo" )
    echo "This script requires privileges"
    echo "to install packages and write to top-level files / directories."
    echo "Invoking \`${a_privilege[*]}' to acquire the permission:"
# "${a_privilege[@]}"：shell 變量展開（variable expansion）的語法，將變量 $a_privilege 展開成一個數組 (array)。[@] 表示將數組中的所有元素展開，並用空格分隔開來。假設 $a_privilege 包含 ("sudo" "root") 這兩個元素，展開後的結果為 "sudo" "root"。
# bash -c ":" 創建一個新的 Bash shell，然後在這個 shell 中執行 ":" 命令，最後退出這個 shell。由於 : 命令什麼也不做，因此這個命令只是為了獲取權限，並不執行實際的操作。
    "${a_privilege[@]}" bash -c ":"
fi

# install docker
"${a_privilege[@]}" apt-get -y install ca-certificates curl wget gnupg lsb-release
"${a_privilege[@]}" mkdir -p /etc/apt/keyrings
# check if ubuntu or debian
if grep -q "Ubuntu" /etc/issue;
then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | "${a_privilege[@]}" gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | "${a_privilege[@]}" tee /etc/apt/sources.list.d/docker.list > /dev/null
else
  curl -fsSL https://download.docker.com/linux/debian/gpg | "${a_privilege[@]}" gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | "${a_privilege[@]}" tee /etc/apt/sources.list.d/docker.list > /dev/null
fi
"${a_privilege[@]}" chmod a+r /etc/apt/keyrings/docker.gpg
"${a_privilege[@]}" apt-get update
"${a_privilege[@]}" apt-get -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
curl -s https://api.github.com/repos/docker/compose/releases/latest | grep browser_download_url  | grep docker-compose-linux-x86_64 | cut -d '"' -f 4 | wget -qi -
chmod +x docker-compose-linux-x86_64
"${a_privilege[@]}" mv docker-compose-linux-x86_64 /usr/local/bin/docker-compose
"${a_privilege[@]}" usermod -aG docker "$USER"
"${a_privilege[@]}" systemctl enable docker
# download docker images
"${a_privilege[@]}" docker pull staticfloat/nginx-certbot
"${a_privilege[@]}" docker pull mcr.microsoft.com/dotnet/samples:aspnetapp

# download /etc/nginx conf files
# sudo sed -i "s/@fqdn/$fqdn/g" /etc/nginx/conf.d/01.aspnetcore.conf 可將檔案中的 "@fqdn" 置換成 fqdn 參數內容，由範本動態產生檔案很好用
"${a_privilege[@]}" mkdir /etc/nginx
"${a_privilege[@]}" mkdir /etc/nginx/conf.d
"${a_privilege[@]}" curl -o /etc/nginx/nginx.conf https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/etc/nginx/nginx.conf
"${a_privilege[@]}" curl -o /etc/nginx/conf.d/00.default.conf https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/etc/nginx/conf.d/00.default.conf
"${a_privilege[@]}" curl -o /etc/nginx/conf.d/01.aspnetcore.conf https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/etc/nginx/conf.d/01.aspnetcore.conf
"${a_privilege[@]}" sed -i "s/@fqdn/$fqdn/g" /etc/nginx/conf.d/01.aspnetcore.conf

# copy docker-compose.yml to $HOME/dockers/nginx-certbot
mkdir -p "$HOME/dockers/nginx-certbot"
cd "$HOME/dockers/nginx-certbot"
curl -O https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/dockers/nginx-certbot/docker-compose.yml
sed -i "s/@email/$email/g" docker-compose.yml

# copy docker-compose.yml to $HOME/dockers/aspnetcore
mkdir -p "$HOME/dockers/aspnetcore"
cd "$HOME/dockers/aspnetcore"
curl -O https://raw.githubusercontent.com/darkthread/nginx-certbot-docker-nstaller/master/dockers/aspnetcore/docker-compose.yml

# start docker containers
cd "$HOME/dockers/aspnetcore"
"${a_privilege[@]}" docker-compose up -d
cd "$HOME/dockers/nginx-certbot"
"${a_privilege[@]}" docker-compose up -d
