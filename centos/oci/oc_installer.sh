#!/bin/bash -e
#Organizr CentOS Installer
#author: elmerfdz
version=v1.2.0-1-super_exp

#Org Requirements
orgreqname=('Unzip' 'NGINX' 'PHP' 'PHP-ZIP' 'PDO:SQLite' 'PHP cURL' 'PHP simpleXML' 'PHP XMLrpc')
orgreq=('unzip' 'nginx' 'php-fpm' 'php-zip' 'php-sqlite3' 'php-curl' 'php-xml' 'php-xmlrpc')


#Nginx config variables
NGINX_LOC='/etc/nginx'
NGINX_SITES='/etc/nginx/sites-available'
NGINX_SITES_ENABLED='/etc/nginx/sites-enabled'
NGINX_CONFIG='/etc/nginx/config'
WEB_DIR='/var/www'
SED=`which sed`
CURRENT_DIR=`dirname $0`
tmp='/tmp/Organizr'
dlvar=0
cred_folder='/etc/letsencrypt/.secrets/certbot'
LE_WEB='/var/www/letsencrypt/.well-known/acme-challenge'

#Modules
#Organizr Requirement Module
orgreq_mod() { 
        echo
        echo -e "\e[1;36m> Updating apt repositories...\e[0m"
		echo
		yum update
		echo

        echo -e "\e[1;36m> Adding SEMANAGE (policycoreutils-python) package...\e[0m"
		yum -y install policycoreutils-python
		echo

        echo -e "\e[1;36m> Adding WHICH  package...\e[0m"
		yum -y install which
		echo					

        #echo -e "\e[1;36m> Disabling Apache if installed...\e[0m"	    
		#service httpd stop
		#systemctl disable httpd
        #        echo

        echo -e "\e[1;36m> Adding CentOS EPEL package...\e[0m"
		yum -y install epel-release
		echo

        echo -e "\e[1;36m> Adding WGET package...\e[0m"
		yum -y install wget
		echo		

        echo -e "\e[1;36m> Adding Nginx source repo...\e[0m"
		cp $CURRENT_DIR/config/nginx/nginx.repo /etc/yum.repos.d/nginx.repo
		echo

        echo -e "\e[1;36m> Adding PHP7+ repositories & Yum utils...\e[0m"
		yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
		yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
		yum -y install yum-utils
		yum-config-manager --enable remi-php72
		yum -y install php php-mcrypt php-cli php-gd php-curl php-mysql php-ldap php-zip php-fileinfo
		
		echo
		for ((i=0; i < "${#orgreqname[@]}"; i++)) 
		do
		    echo -e "\e[1;36m> Installing ${orgreqname[$i]}...\e[0m"
		    echo
		    yum -y install ${orgreq[$i]}
		    echo
		done

                echo -e "\e[1;36m> Configuring Nginx...\e[0m"	
		mkdir -p /etc/nginx/sites-available
		mkdir -p /etc/nginx/sites-enabled
		cp $CURRENT_DIR/config/nginx/nginx.conf /etc/nginx
		systemctl enable nginx
		systemctl start nginx
		systemctl reload nginx
		systemctl restart nginx
		echo

                echo -e "\e[1;36m> Configuring PHP...\e[0m"
		cp $CURRENT_DIR/config/php/www.conf /etc/php-fpm.d
		systemctl enable php-fpm
		systemctl start php-fpm	
		systemctl stop php-fpm
		systemctl start php-fpm
		systemctl reload php-fpm	
		systemctl restart php-fpm
		echo
                }

#SELinux config
selinux_mod() { 
        echo
        echo -e "\e[1;36m> Configuring SELinux settings...\e[0m"
		for run in {1..2}
		do
		semanage fcontext -a -t httpd_sys_content_t '/var/www(/.*)?' >/dev/null 2>&1
		semanage fcontext -a -t httpd_sys_rw_content_t '/var/www(/.*)?'		
		restorecon -Rv /var/www >/dev/null
		systemctl restart nginx
		systemctl restart php-fpm
		done
		echo
        echo -e "\e[1;36m> Enabling site access over local network...\e[0m"
		echo -e "\e[1;36m> - Enabling  HTTP service\e[0m"
		firewall-cmd --permanent --zone=public --add-service=http
		echo -e "\e[1;36m> - Enabling  HTTPS service\e[0m"
		firewall-cmd --permanent --zone=public --add-service=https
		echo -e "\e[1;36m> - Reload firewall-cmd\e[0m"		
		firewall-cmd --reload
		echo
		
                }

#Domain validation 
domainval_mod()
	{
		while true
		do
			echo -e "\e[1;36m> Enter a domain or a folder name for your install:\e[0m" 
			echo -e "\e[1;36m> E.g domain.com / organizr.local / $(hostname).local / anything.local] \e[0m" 
			printf '\e[1;36m- \e[0m'
			read -r dname
			DOMAIN=$dname
	
			# check the domain is roughly valid!
			PATTERN="^([[:alnum:]]([[:alnum:]\-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,10}$"
			if [[ "$DOMAIN" =~ $PATTERN ]]; then
			DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
			echo -e "\e[1;36m> \e[0mCreating vhost file for:" $DOMAIN
			break
			else
			echo "> invalid domain name"
			echo
			fi
		done	
	}
#Nginx vhost creation module

vhostcreate_mod()        
       {
        	echo
		#domainval_mod
		# Copy the virtual host template
		CONFIG=$NGINX_SITES/$DOMAIN.conf
		echo -e "\e[1;36m> Nginx vhost template type?:\e[0m"
		echo
		echo -e "\e[1;36m[CF] \e[0mCloudFlare"
		echo -e "\e[1;36m[LE] \e[0mLet's Encrypt/Standard [coming soon]"
		echo
		printf '\e[1;36m- \e[0m'
		read -r vhost_template
		vhost_template=${vhost_template:-CF}
		
		CFvhostcreate_mod
		LEvhostcreate_mod


		# set up web root
		chmod 755 $CONFIG

		# create symlink to enable site
		ln -s $CONFIG $NGINX_SITES_ENABLED/$DOMAIN.conf

		echo -e "\e[1;36m> \e[0mSite Created for $DOMAIN"
		echo
       }
CFvhostcreate_mod()        
       {
		systemctl start nginx
		if [ "$org_v" == "1" ] && [ "$vhost_template" == "CF" ]
		then
		cp $CURRENT_DIR/templates/orgv1_cf.template $CONFIG
		cp -a $CURRENT_DIR/config/cf/. $NGINX_LOC/config
		mv $NGINX_LOC/config/domain.com.conf $NGINX_LOC/config/$DOMAIN.conf
		mv $NGINX_LOC/config/domain.com_ssl.conf $NGINX_LOC/config/${DOMAIN}_ssl.conf
		CONFIG_DOMAIN=$NGINX_CONFIG/$DOMAIN.conf
		mkdir -p $NGINX_CONFIG/ssl/$DOMAIN
		chmod -R 755 $NGINX_CONFIG/ssl/$DOMAIN

		elif [ "$org_v" == "2" ] && [ "$vhost_template" == "CF" ]
		then
		cp $CURRENT_DIR/templates/orgv2_cf.template $CONFIG
		cp -a $CURRENT_DIR/config/cf/. $NGINX_LOC/config
		mv $NGINX_LOC/config/domain.com.conf $NGINX_LOC/config/$DOMAIN.conf
		mv $NGINX_LOC/config/domain.com_ssl.conf $NGINX_LOC/config/${DOMAIN}_ssl.conf
		CONFIG_DOMAIN=$NGINX_CONFIG/$DOMAIN.conf
		mkdir -p $NGINX_CONFIG/ssl/$DOMAIN
		chmod -R 755 $NGINX_CONFIG/ssl/$DOMAIN
		fi

	}

LEvhostcreate_mod()        
       {
		echo
		if [ "$vhost_template" == "LE" ] || [ "$vhost_template" == "le" ]; 
		then
			echo -e "\e[1;36m> Do you want to generate Let's Encrypt SSL certs as well? [y/n].\e[0m"
			printf '\e[1;36m- \e[0m'
			read -r LEcert_create
			LEcert_create=${LEcert_create:-Y}
			if [ "$LEcert_create" == "Y" ] || [ "$LEcert_create" == "y" ];
			then		
				echo -e "\e[1;36m> Please note, since you've selected the Let's Encrypt Option, will start by preparing your system to generte LE SSL certs.\e[0m" 
				echo -e "\e[1;36m> Please make sure, you've configured your domain with the correct DNS records.\e[0m"
				echo -e "\e[1;36m> If you're using CloudFlare (CF) as your DNS, then this is supported by this option.\e[0m"
				echo -e "\e[1;36m> If you haven't preparared your setup to carry out the above, then please terminate this script.\e[0m"
				echo 
				echo -e "\e[1;36m> Or press any key to continue...\e[0m"		 
				read 
				echo 
				echo -e "\e[1;36m> LE Cert type?:\e[0m"
				echo
				echo -e "\e[1;36m[S] \e[0mSingle Domain Cert"
				echo -e "\e[1;36m[W] \e[0mWildcard"
				echo
				printf '\e[1;36m- \e[0m'
				read -r LEcert_type
				LEcert_type=${LEcert_type:-W}
			

				if [ "$LEcert_type" == "W" ] || [ "$LEcert_type" == "w" ];
				then
					echo
					echo -e "\e[1;36m> Is your domain on Cloudflare? [y/n] .\e[0m"
					echo  "- Going ahead with the above will automate the DNS / dns-01 challenges for you."
					echo  "- To do that, python3-pip & certbot-dns-cloudflare pip3 package wll be installed"
					printf '\e[1;36m- [y/n]: \e[0m'
					read -r dns_plugin
					dns_plugin=${dns_plugin:-n}
					echo		
				fi
			fi	
		
			mkdir -p $NGINX_APPS 								#Apps folder
			mkdir -p $NGINX_CONFIG/$DOMAIN
			cp -a $CURRENT_DIR/config/apps/. $NGINX_APPS  		#Apps conf files
			cp -a $CURRENT_DIR/config/le/. $NGINX_CONFIG/$DOMAIN 	#LE conf file

			if [ "$org_v" == "1" ] && [ "$vhost_template" == "LE" ] || [ "$vhost_template" == "le" ]
			then
				LEcertbot_mod
				if [ "$LEcert_create" == "Y" ] || [ "$LEcert_create" == "y" ]
				then
					cp $CURRENT_DIR/templates/le/orgv1_le.template $CONFIG
					if [ "$LEcert_type" == "W" ] || [ "$LEcert_type" == "w" ]
					then
						subd='www'
						subd_doma="$DOMAIN" 
						serv_name="$subd.$DOMAIN $DOMAIN"  		
			
					elif [ "$LEcert_type" == "S" ] || [ "$LEcert_type" == "s" ]
					then
						subd_doma="$DOMAIN"
						serv_name="$DOMAIN"   
						#Create LE Certbot renewal cron job
					fi

				elif [ "$LEcert_create" == "N" ] || [ "$LEcert_create" == "n" ]
				then
						cp $CURRENT_DIR/templates/le/orgv1_le_no_ssl.template $CONFIG
						subd_doma="$DOMAIN"
						serv_name="$DOMAIN"   
				fi	
					
			elif [ "$org_v" == "2" ] && [ "$vhost_template" == "LE" ] || [ "$vhost_template" == "le" ]
			then
				LEcertbot_mod
				if [ "$LEcert_create" == "Y" ] || [ "$LEcert_create" == "y" ]
				then
					cp $CURRENT_DIR/templates/le/orgv2_le.template $CONFIG				
					if [ "$LEcert_type" == "W" ] || [ "$LEcert_type" == "w" ]
					then
						subd='www'
						subd_doma="$DOMAIN" 
						serv_name="$subd.$DOMAIN $DOMAIN"  				
							
					elif [ "$LEcert_type" == "S" ] || [ "$LEcert_type" == "s" ]
					then
						subd_doma="$DOMAIN"
						serv_name="$DOMAIN" 
					fi

				elif [ "$LEcert_create" == "N" ] || [ "$LEcert_create" == "n" ]
				then
						cp $CURRENT_DIR/templates/le/orgv2_le_no_ssl.template $CONFIG
						subd_doma="$DOMAIN"
						serv_name="$DOMAIN"   				
				fi		
			fi
		fi	
		}

LEcertbot_mod() 
		{
			if [ ! -d "$LE_WEB" ]; then
			mkdir -p $LE_WEB
			fi
			
			#Configuring permissions on LE web folder
			chmod -R 775 $LE_WEB
			chown -R nginx:$(logname) $LE_WEB

			#Copy LE TEMP conf file so that LE can connect to server and continue to generate the certs
			cp $CURRENT_DIR/templates/le/le_temp.template $CONFIG
			$SED -i "s/DOMAIN/$DOMAIN/g" $CONFIG
			
			#Delete default.conf nginx site
			mkdir -p $tmp/bk/nginx_default_site
 			if [ -e $NGINX_SITES/default ] 
			then cp -a $NGINX_SITES/default $tmp/bk/nginx_default_site
			fi			
			rm -r -f $NGINX_SITES/default
			rm -r -f $NGINX_SITES_ENABLED/default

			# create symlink to enable site
			ln -s $CONFIG $NGINX_SITES_ENABLED/$DOMAIN.conf

			if [ "$LEcert_create" == "Y" ] || [ "$LEcert_create" == "y" ];
			then 
				# reload Nginx to pull in new config
				nginx -s reload
				##Install certbot packages
				yum -y install yum-utils
				yum-config-manager --enable rhui-REGION-rhel-server-extras rhui-REGION-rhel-server-optional
				yum install python2-certbot-nginx
			fi

			if [ "$dns_plugin" == "Y" ] || [ "$dns_plugin" == "y" ]
			then
				echo
				echo -e "\e[1;36m> Enter your Cloudflare email.\e[0m"
				printf '\e[1;36m- \e[0m' 
				read -r CF_EMAIL
				echo
				echo -e "\e[1;36m> Enter your Cloudflare API.\e[0m" 
				echo "- You can get your Cloudflare API from here: https://dash.cloudflare.com/profile"
				printf '\e[1;36m- \e[0m' 
				read -r CF_API
				echo
				yum -y install python2-certbot-dns-cloudflare

			mkdir -p $cred_folder #create secret folder to store Certbot CF plugin creds
			cp -a $CURRENT_DIR/config/le-dnsplugins/cf/. $cred_folder #copy CF credentials file
			#Update CF plugin file
			$SED -i "s/CF_EMAIL/$CF_EMAIL/g" $cred_folder/cloudflare.ini
			$SED -i "s/CF_API/$CF_API/g" $cred_folder/cloudflare.ini
			chmod -R 600 $cred_folder #debug

			elif [ "$dns_plugin" == "N" ] || [ "$dns_plugin" == "n" ]
			then
				apt-get install certbot -y
			fi

			if [ "$LEcert_create" == "Y" ] || [ "$LEcert_create" == "y" ];
			then
				## Get wildcard certificate, Let's Encrypt
				echo
				echo -e "\e[1;36m> Enter an email address, which will be used to generate the SSL certs?.\e[0m"
				if [ "$dns_plugin" == "Y" ] || [ "$dns_plugin" == "y" ];
				then
					echo -e "- Press Enter to use \e[1;36m$CF_EMAIL\e[0m or enter a different one"
				fi
				read -r email_var
				email_var=${email_var:-$CF_EMAIL}
			fi	

			if [ "$LEcert_type" == "W" ] || [ "$LEcert_type" == "w" ]
			then
				if [ "$dns_plugin" == "Y" ] || [ "$dns_plugin" == "y" ]
				then
					certbot certonly --dns-cloudflare --dns-cloudflare-credentials $cred_folder/cloudflare.ini --server https://acme-v02.api.letsencrypt.org/directory --email $email_var --agree-tos --no-eff-email -d *.$DOMAIN -d $DOMAIN
					#Adding wildcar cert auto renewal using CF DNS plugin, untested, let me know if anyone does.
					{ crontab -l 2>/dev/null; echo "20 3 * * * certbot renew --noninteractive --dns-cloudflare --renew-hook "'"/etc/init.d/nginx reload"'""; } | crontab -
				
				elif [ "$dns_plugin" == "N" ] || [ "$dns_plugin" == "n" ]
				then
					certbot certonly --agree-tos --no-eff-email --email $email_var --server https://acme-v02.api.letsencrypt.org/directory --manual -d *.$DOMAIN -d $DOMAIN
				fi
			
			elif [ "$LEcert_type" == "S" ] || [ "$LEcert_type" == "s" ]
			then
				certbot certonly --webroot --agree-tos --no-eff-email --email $email_var -w /var/www/letsencrypt -d $DOMAIN -d $DOMAIN
				#Create LE Certbot renewal cron job
				{ crontab -l 2>/dev/null; echo "20 3 * * * certbot renew --noninteractive --renew-hook "'"/etc/init.d/nginx reload"'""; } | crontab -
			fi

			## Once Cert has been generated, delete the created conf file.
			rm -r -f $NGINX_SITES/$DOMAIN.conf
			rm -r -f $NGINX_SITES_ENABLED/$DOMAIN.conf
		}		

#Organizr download module
orgdl_mod()
        {
		echo
		echo -e "\e[1;36m> which version of Organizr do you want to install?.\e[0m" 
		echo -e "\e[1;36m[1] \e[0mOrganizr v1"
		echo -e "\e[1;36m[2] \e[0mOrganizr v2" 
		echo 
		printf '\e[1;36m> \e[0m'
		read -r org_v
		echo
		echo -e "\e[1;36m> which branch do you want to install?\e[0m .eg. 1a or 2a"
		echo
		if [ $org_v = "1" ]
		then 
		echo -e "\e[1;36m[1a] \e[0mMaster"
		echo -e "\e[1;36m[1b] \e[0mDev"
		echo -e "\e[1;36m[1c] \e[0mPre-Dev"
		
		elif [ $org_v = "2" ]
		then 
		echo -e "\e[1;36m[2a] \e[0mMaster"
		echo -e "\e[1;36m[2b] \e[0mDev"
		fi

		echo
		printf '\e[1;36m> Enter branch code: \e[0m'
		read -r dlvar
		echo
 		if [ -z "$DOMAIN" ]; then
		domainval_mod
		 
		fi		
		echo
		echo -e "\e[1;36m> Where do you want to install Organizr? \e[0m"
		echo -e "\e[1;36m> \e[0m [Press Return for Default = /var/www/$DOMAIN]"
		echo
		printf '\e[1;36m- \e[0m'
		read instvar
		instvar=${instvar:-/var/www/$DOMAIN}
		echo
		#Org Download and Install
		if [ $dlvar = "1a" ]
		then 
		dlbranch=Master
		zipbranch=master.zip
		zipextfname=Organizr-master
			
		elif [ $dlvar = "1b" ]
		then 
		dlbranch=Develop
		zipbranch=develop.zip
		zipextfname=Organizr-develop

		elif [ $dlvar = "1c" ]
		then 
		dlbranch=Pre-Dev
		zipbranch=cero-dev.zip
		zipextfname=Organizr-cero-dev

		elif [ $dlvar = "2a" ]
		then
		dlbranch=v2-master
		zipbranch=v2-master.zip
		zipextfname=Organizr-2-master

		elif [ $dlvar = "2b" ]
		then
		dlbranch=v2-develop
		zipbranch=v2-develop.zip
		zipextfname=Organizr-2-develop
		fi

		echo -e "\e[1;36m> Downloading the latest Organizr "$dlbranch" ...\e[0m"
		rm -r -f /tmp/Organizr/$zipbranch
		rm -r -f /tmp/Organizr/$zipbranch.*		
		rm -r -f /tmp/Organizr/$zipextfname
		wget https://github.com/causefx/Organizr/archive/$zipbranch -P /tmp/Organizr/ 
		unzip -q /tmp/Organizr/$zipbranch -d /tmp/Organizr
		echo -e "\e[1;36m> Organizr "$dlbranch" downloaded and unzipped \e[0m"
		echo
		echo -e "\e[1;36m> Installing Organizr...\e[0m"

		if [ ! -d "$instvar" ]; then
		mkdir -p $instvar
		fi
		cp -a /tmp/Organizr/$zipextfname/. $instvar/html
                
		if [ ! -d "$instvar/db" ]; then
		mkdir $instvar/db
		fi
		#Configuring permissions on web folder
		chmod -R 775 $instvar
		chown -R nginx:$(logname) $instvar
        }
#Nginx vhost config
vhostconfig_mod()
        {      
		#Add in your domain name to your site nginx conf files
		SITE_DIR=`echo $instvar`
		$SED -i "s/DOMAIN/$DOMAIN/g" $CONFIG
		$SED -i "s|ROOT|$SITE_DIR|g" $CONFIG
		$SED -i "s/DOMAIN/$DOMAIN/g" $CONFIG_DOMAIN
		#phpv=$(ls -t /etc/php | head -1)
		$SED -i "s/VER/$phpv/g" $NGINX_CONFIG/phpblock.conf

		#Delete default.conf nginx site
		mkdir -p $tmp/bk/nginx_default_site
 		if [ -e $NGINX_LOC/conf.d/default.conf ] 
		then cp -a $NGINX_LOC/conf.d/default.conf $tmp/bk/nginx_default_site
		fi			
		rm -r -f $NGINX_LOC/conf.d/default.conf
		#rm -r -f $NGINX_SITES_ENABLED/conf.d/default.conf
			
		# reload Nginx to pull in new config
		nginx -s reload
        }

#Add site to hosts for local access
addsite_to_hosts_mod()
        {
		echo "127.0.0.1 $DOMAIN" >> /etc/hosts
	}

#Org Install info
orginstinfo_mod()
        {
		#Displaying installation info
		echo
		printf '######################################################'
		echo
		echo -e "     	 \e[1;32mOrganizr $q Installion Complete  \e[0m"
		printf '######################################################'
		echo
		echo
		echo -------------------------------------------------------
		echo -e " 	   \e[1;36mAbout your Organizr install    	\e[0m"
		echo -------------------------------------------------------
		echo -e "\e[1;34mInstall directory\e[0m     = $instvar"
		echo -e "\e[1;34mOrganzir files stored\e[0m = $instvar/html "
		echo -e "\e[1;34mOrganzir db directory\e[0m = $instvar/db "
		if [ "$options" != "2" ] 
		then
		echo -e "      \e[1;34mDomain added to\e[0m = /etc/hosts "
		fi
		echo -------------------------------------------------------
		echo
		echo "> Use the above db path when you're setting up the admin user"
		if [ "$options" == "1" ] || [ "$options" == "4" ] 
		then
		echo -e "> Open \e[1;36mhttp://$DOMAIN/\e[0m to create the admin user/setup your DB directory and finalise your Organizr Install"
		echo

		elif [ "$options" == "2" ]
		then
		echo "- Next if you haven't done already, create or configure your Nginx conf to point to the Org installation directoy"
		echo
		fi
        }
#OUI script Updater
oui_updater_mod()
	{
			echo
			echo "Which branch of OUI, do you want to install?"
			echo "- [1] = Master [2] = Dev [3] = Experimental"
			read -r oui_branch_no
			echo

			if [ $oui_branch_no = "1" ]
			then 
			oui_branch_name=master
				
			elif [ $oui_branch_no = "2" ]
			then 
			oui_branch_name=dev
	
			elif [ $oui_branch_no = "3" ]
			then 
			oui_branch_name=experimental
			fi

		    	git fetch --all
			git reset --hard origin/$oui_branch_name
			git pull origin $oui_branch_name
			echo
                	echo -e "\e[1;36mScript updated, reloading now...\e[0m"
			sleep 3s
			chmod +x $BASH_SOURCE
			exec ./oc_installer.sh
	}
#Utilities sub-menu
uti_menus() 
	{
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo -e " 	  \e[1;36mOUI: $version : Utilities  \e[0m"
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo " 1. < None - Placeholder > 	  " 
		echo " 2. Back 					  "
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo
		printf "\e[1;36m> Enter your choice: \e[0m"
	}
#Utilities sub-menu-options
uti_options(){
		read -r options
		case $options in
	 	"1")
			echo "- Your choice 1: None"
			echo
			echo			
                	echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
		;;

		"2")
			while true 
			do
			clear
			show_menus
			read_options
			done
		;;

	      	esac
	     }


show_menus() 
	{
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo -e " 	  \e[1;36mORGANIZR CENTOS - INSTALLER $version  \e[0m"
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo " 1. Organizr + Nginx site Install		  " 
		echo " 2. Organizr Web Folder Only Install		 "
		echo " 3. Organizr Requirements Install		  "
		echo " 4. Organizr Complete Install (Org + Requirements) "
		echo " 5. OUI Auto Updater				  "
		echo " 6. Utilities				  "
		echo " 7. Quit 					  "
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo
		printf "\e[1;36m> Enter your choice: \e[0m"
	}
read_options(){
		read -r options

		case $options in
	 	"1")
			echo "- Your choice: 1. Organizr + Nginx site Install"
			orgdl_mod
			vhostcreate_mod
			vhostconfig_mod
			addsite_to_hosts_mod
			selinux_mod
			orginstinfo_mod
			unset DOMAIN
                	echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
		;;

	 	"2")
			echo "- Your choice 2: Organizr Web Folder Only Install"
			orgdl_mod
			selinux_mod
			orginstinfo_mod
			#echo "- Next if you haven't done already, configure your Nginx conf to point to the Org installation directoy"
			echo
			unset DOMAIN
                	echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
		;; 

	 	"3")
			echo "- Your choice 3: Install Organzir Requirements"
			orgreq_mod
                	echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
		;;
        
	 	"4")
			echo "- Your choice 4: Organizr Complete Install (Org + Requirements) "
	        	orgreq_mod
			echo -e "\e[1;36m> \e[0mPress any key to continue with Organizr + Nginx site config"
			read
			orgdl_mod
	        	vhostcreate_mod
			vhostconfig_mod
			addsite_to_hosts_mod
			selinux_mod
			orginstinfo_mod
			unset DOMAIN
                	echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
		;;

	 	"5")
	        	oui_updater_mod
		;;

		"6")
			while true 
			do
			clear
			uti_menus
			uti_options
			done
		;;

		"7")
			exit 0
		;;


	      	esac
	     }

while true 
do
	clear
	show_menus
	read_options
done









