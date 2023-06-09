#!/bin/bash

# Check if the script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "\nPlease run the script as super-user (sudo)."
  exit
fi

# Check if VSC is installed
found_vsc=false
if command -v code &>/dev/null; then
  found_vsc=true
fi

# Beginning Indicator
echo -e "\n==========================="
echo -e "=- TALL STACKER |> SETUP -="
echo -e "===========================\n"

origin_dir=$PWD

# Get environment variables and defaults
source $origin_dir/.env

# Make the helper script executable
sudo chmod +x $TALL_STACKER_DIRECTORY/scripts/helpers/permit.sh

# * ================
# * System Packages
# * ==============

# git, php, apache2, redis and npm
sudo apt install git curl php apache2 php-curl php-xml php-dom php-bcmath php-zip redis-server npm -y >/dev/null 2>&1

sudo sed -i "s~post_max_size = 8M~post_max_size = 100M~g" /etc/php/8.1/apache2/php.ini
sudo sed -i "s~upload_max_filesize = 2M~upload_max_filesize = 100M~g" /etc/php/8.1/apache2/php.ini
sudo sed -i "s~variables_order = \"GPCS\"~variables_order = \"EGPCS\"~g" /etc/php/8.1/apache2/php.ini

sudo systemctl start apache2 >/dev/null 2>&1
sudo a2enmod rewrite >/dev/null 2>&1
sudo systemctl restart apache2 >/dev/null 2>&1
sudo a2enmod ssl >/dev/null 2>&1
sudo systemctl restart apache2 >/dev/null 2>&1

echo -e "Installed Git, PHP, Apache, Redis and npm packages."

# Grant user write permissions
sudo usermod -a -G www-data $USERNAME

echo -e "\nAdded the environment's user to [www-data] group."

# media packages
sudo apt install php-imagick php-gd ghostscript ffmpeg -y >/dev/null 2>&1

echo -e "\nInstalled media packages. (imagick, GD, etc.)"

# Xdebug
sudo apt install php-xdebug -y >/dev/null 2>&1

mkdir -p /home/$USERNAME/.config/xdebug

sudo sed -i "s~zend_extension=xdebug.so~zend_extension=xdebug.so\n\nxdebug.log=\"/home/$USERNAME/.config/xdebug/xdebug.log\"\nxdebug.log_level=10\nxdebug.mode=develop,debug,coverage\nxdebug.client_port=9003\nxdebug.start_with_request=yes\nxdebug.discover_client_host=true~g" /etc/php/8.1/mods-available/xdebug.ini

sudo $TALL_STACKER_DIRECTORY/scripts/helpers/permit.sh /home/$USERNAME/.config/xdebug

sudo systemctl restart apache2 >/dev/null 2>&1

echo -e "\nInstalled PHP Xdebug."

# NodeJS Upgrades
sudo -i -u $USERNAME bash <<EOF >/dev/null 2>&1
cd /home/$USERNAME/Downloads &&
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash &&
source /home/$USERNAME/.bashrc &&
nvm install 14 &&
nvm use 14 &&
npm install -g npm@8.5.1
EOF

# Composer (globally)
sudo apt install composer -y >/dev/null 2>&1

echo -e "\nexport PATH=\"\$PATH:/home/$USERNAME/.config/composer/vendor/bin\"" >> /home/$USERNAME/.bashrc >/dev/null 2>&1
source /home/$USERNAME/.bashrc

echo -e "\nInstalled composer globally."

# mkcert
sudo apt install mkcert libnss3-tools -y >/dev/null 2>&1

sudo -i -u $USERNAME bash <<EOF >/dev/null 2>&1
mkcert -install
EOF

echo -e "\nInstalled mkcert for SSL generation."

# MySQL
sudo apt install mysql-server -y >/dev/null 2>&1

sudo systemctl start mysql

sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_PASSWORD';"

sudo apt install php-mysql -y >/dev/null 2>&1

sudo service apache2 restart

echo -e "\nInstalled MySQL and set the password to the environment's."

# Mailpit (service)
mkdir /home/$USERNAME/Downloads/mailpit
cd /home/$USERNAME/Downloads/mailpit

release_url=$(curl -s https://api.github.com/repos/axllent/mailpit/releases/latest | grep "browser_download_url.*mailpit-linux-amd64.tar.gz" | cut -d : -f 2,3 | tr -d \")
curl -L -o mailpit-linux-amd64.tar.gz $release_url >/dev/null 2>&1

tar -xzf mailpit-linux-amd64.tar.gz
sudo chown $USERNAME:$USERNAME mailpit
sudo chmod +x mailpit
sudo mv mailpit /usr/local/bin/

cd ..
sudo rm -rf mailpit

echo "[Unit]
Description=Mailpit
After=network.target

[Service]
User=$USERNAME
Group=$USERNAME
WorkingDirectory=/usr/local/bin
ExecStart=/usr/local/bin/mailpit
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/mailpit.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable mailpit.service >/dev/null 2>&1
sudo systemctl start mailpit.service

echo -e "\nInstalled Mailpit and set up a service for it."

# MinIO (server, client and service)
mkdir /home/$USERNAME/Downloads/minio
cd /home/$USERNAME/Downloads/minio

wget https://dl.min.io/server/minio/release/linux-amd64/minio >/dev/null 2>&1
wget https://dl.min.io/client/mc/release/linux-amd64/mc >/dev/null 2>&1

sudo chown $USERNAME:$USERNAME minio
sudo chmod +x minio
sudo chown $USERNAME:$USERNAME mc
sudo chmod +x mc

sudo mv minio /usr/local/bin/
sudo mv mc /usr/local/bin/minio-client

cd ..
sudo rm -rf minio

mkdir -p /home/$USERNAME/.config/minio/data

sudo chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/minio/data

echo "[Unit]
Description=MinIO
After=network.target

[Service]
User=$USERNAME
Group=$USERNAME
WorkingDirectory=/usr/local/bin
ExecStart=/usr/local/bin/minio server /home/$USERNAME/.config/minio/data
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/minio.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable minio.service >/dev/null 2>&1
sudo systemctl start minio.service

sudo -i -u $USERNAME bash <<EOF >/dev/null 2>&1
minio-client alias set myminio/ http://localhost:9000 minioadmin minioadmin >/dev/null 2>&1
EOF

echo -e "\nInstalled MinIO and set up a service for it."

# Expose
cd /home/$USERNAME/Downloads
curl https://github.com/beyondcode/expose/raw/master/builds/expose -L --output expose >/dev/null 2>&1

sudo chown $USERNAME:$USERNAME expose
sudo chmod +x expose

sudo mv expose /usr/local/bin/

sudo -i -u $USERNAME bash <<EOF >/dev/null 2>&1
expose token $EXPOSE_TOKEN
EOF

echo -e "\nInstalled Expose and set up its token to be ready to use."

# * ==================
# * Opinionated Setup
# * ================

if [ "$OPINIONATED" == true ]; then
  # CodeSniffer
  composer global require "squizlabs/php_codesniffer=*" --dev --quiet

  sudo mkdir $PROJECTS_DIRECTORY/.shared
  sudo cp $TALL_STACKER_DIRECTORY/files/.shared/phpcs.xml $PROJECTS_DIRECTORY/.shared/

  sudo $TALL_STACKER_DIRECTORY/scripts/helpers/permit.sh $PROJECTS_DIRECTORY/.shared

  echo -e "\nInstalled CodeSniffer globally."

  # Link projects directory
  mkdir /home/$USERNAME/Code >/dev/null 2>&1

  sudo -i -u $USERNAME bash <<EOF >/dev/null 2>&1
  cd /home/$USERNAME/Code
  ln -s $PROJECTS_DIRECTORY/
  final_folder=$(basename $PROJECTS_DIRECTORY)
  mv $final_folder TALL
EOF

  sudo $TALL_STACKER_DIRECTORY/scripts/helpers/permit.sh /home/$USERNAME/Code

  echo -e "\nLinked projects directory into [~/Code/TALL] directory."

  # Install Firacode font (if VSC installed)
  if [[ $found_vsc == true ]]; then
    sudo apt install fonts-firacode -y >/dev/null 2>&1

    echo -e "\nInstalled Firacode font for VSC."
  fi

  # Create .packages directory
  sudo mkdir $PROJECTS_DIRECTORY/.packages

  sudo $TALL_STACKER_DIRECTORY/scripts/helpers/permit.sh $PROJECTS_DIRECTORY/.packages

  echo -e "\nCreated a .packages directory."
fi

# ! DONE

touch $origin_dir/done-setup
