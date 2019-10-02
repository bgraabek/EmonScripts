#!/bin/bash
source load_config.sh

echo "-------------------------------------------------------------"
echo "Install Emoncms Core"
echo "-------------------------------------------------------------"

# Give user ownership over /var/www/ folder
sudo chown $user /var/www

# Install emoncms core repository with git
if [ ! -d $emoncms_www ]; then
    cd /var/www && git clone -b $emoncms_core_branch ${git_repo[emoncms_core]}
    cd
else
    echo "- emoncms already installed"
fi

# Create emoncms logfolder
if [ ! -f $emoncms_log_location ]; then
    echo "- creating emoncms log folder"
    sudo mkdir $emoncms_log_location
    sudo chown $user $emoncms_log_location
    sudo touch "$emoncms_log_location/emoncms.log"
    sudo chmod 666 "$emoncms_log_location/emoncms.log"
else
    echo "- log folder already exists"
fi

# Copy and install emonpi.settings.ini
if [ ! -f $emoncms_www/settings.ini ]; then
    echo "- installing default emoncms settings.ini"
    cp $openenergymonitor_dir/EmonScripts/defaults/emoncms/emonpi.settings.ini $emoncms_www/settings.ini
    sed -i "s~EMONCMS_DIR~$emoncms_dir~" $emoncms_www/settings.ini
    sed -i "s~OPENENERGYMONITOR_DIR~$openenergymonitor_dir~" $emoncms_www/settings.ini
    sed -i "s~EMONCMS_DATADIR~$emoncms_datadir~" $emoncms_www/settings.ini
else
    echo "- emoncms settings.ini already exists"
fi

if [ ! -d $emoncms_datadir ]; then
    sudo mkdir $emoncms_datadir
fi

# Create data directories for emoncms feed engines:
for engine in "phpfina" "phpfiwa" "phptimeseries"; do
    if [ ! -d $emoncms_datadir/$engine ]; then
        echo "- create $engine dir"
        sudo mkdir $emoncms_datadir/$engine
        sudo chown www-data:root $emoncms_datadir/$engine
    else
        echo "- datadir $engine already exists"
    fi
done

if [ ! -d $emoncms_dir ]
then
    sudo mkdir $emoncms_dir
    sudo chown $USER $emoncms_dir
fi

# Create a symlink to reference emoncms within the web root folder (review):
if [ ! -d /var/www/html/emoncms ]; then
    echo "- symlinking emoncms folder to /var/www/html/emoncms"
    sudo ln -s $emoncms_www /var/www/html/emoncms
    
    # Redirect (review)
    echo "- creating redirect to $emoncms_www"
    echo "<?php header('Location: ../emoncms'); ?>" > $emoncms_dir/index.php
    sudo mv $emoncms_dir/index.php /var/www/html/index.php
    sudo rm /var/www/html/index.html
fi

echo "-------------------------------------------------------------"
echo "Install Emoncms Services"
echo "-------------------------------------------------------------"
# Install service-runner drop-in if system user is different
if [ "$user"!="pi" ]; then
    echo "installing service-runner drop-in User=$user"
    sudo mkdir /lib/systemd/system/service-runner.service.d
    echo $'[Service]\nUser='$user > service-runner.conf
    sudo mv service-runner.conf /lib/systemd/system/service-runner.service.d/service-runner.conf

    echo "installing emoncms_mqtt drop-in User=$user"    
    sudo mkdir /lib/systemd/system/emoncms_mqtt.service.d
    echo $'[Service]\nEnvironment="USER=oem"' > emoncms_mqtt.conf
    sudo mv emoncms_mqtt.conf /lib/systemd/system/emoncms_mqtt.service.d/emoncms_mqtt.conf

    echo "installing feedwriter drop-in User=$user"
    sudo mkdir /lib/systemd/system/feedwriter.service.d
    echo $'[Service]\nEnvironment="USER=oem"' > feedwriter.conf
    sudo mv feedwriter.conf /lib/systemd/system/feedwriter.service.d/feedwriter.conf
fi
# Install actual services, enable and start
for service in "emoncms_mqtt" "feedwriter" "service-runner"; do
    servicepath=$emoncms_www/scripts/services/$service/$service.service
    $openenergymonitor_dir/EmonScripts/common/install_emoncms_service.sh $servicepath $service
done
echo

if [ "$emonSD_pi_env" = "1" ]; then  
  # Sudoers entry (review)
  sudo visudo -cf $openenergymonitor_dir/EmonScripts/sudoers.d/emoncms-rebootbutton && \
  sudo cp $openenergymonitor_dir/EmonScripts/sudoers.d/emoncms-rebootbutton /etc/sudoers.d/
  sudo chmod 0440 /etc/sudoers.d/emoncms-rebootbutton
  echo "emonPi emoncms admin reboot button sudoers updated"
fi

echo
