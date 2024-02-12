#!/bin/bash

directory="/etc/otelcol-contrib/otelfiles"
file="/etc/otelcol-contrib/otelfiles/groups.out"
restart=1
puppet_host=$(facter hostname)

# read in groups.out file

while IFS=: read -r host group; do
    # Remove leading/trailing whitespaces
    host=$(echo "$host" | tr -d '[:space:]')
    group=$(echo "$group" | tr -d '[:space:]')

    # Check if the puppet host is present in the current group
    if [ "$host" == "$puppet_host" ]; then
        found_group=$group
        break
    fi
done < "$file"

if [ -n "$found_group" ]; then
    echo "Found host $puppet_host in group: $found_group"
    yaml_content="otel_group: ${found_group}"
    output_file="/opt/puppetlabs/facter/facts.d/otel_group_fact_${found_group}.yaml"
    if [ ! -e $output_file ]; then
      if [ -e /opt/puppetlabs/facter/facts.d/otel_group_fact_*.yaml ]; then
        rm /opt/puppetlabs/facter/facts.d/otel_group_fact_*.yaml
      fi
      echo "$yaml_content" > "$output_file"
      echo "Created YAML file: $output_file"
    fi
else
    echo "Host $puppet_host not found in any group."
    if [ -e /opt/puppetlabs/facter/facts.d/otel_group_fact_*.yaml ]; then
        file_name=$(find /opt/puppetlabs/facter/facts.d/ -type f -name "otel_group_fact_*.yaml" -print -quit)
        group=$(echo "$file_name" | sed -n 's|.*/otel_group_fact_\([^/]*\)\.yaml|\1|p')

        echo "Old group appears to be $group"
        echo "We also need to remove the old group yaml file"
        rm /opt/puppetlabs/facter/facts.d/otel_group_fact_*.yaml
        rm /etc/otelcol-contrib/otelfiles/${group}.yaml
    fi

fi

# At this point we have either put the facts stuff in place or removed old group entries if the host is no longer part of a group

if [ ! -e /etc/otelcol-contrib/otelfiles/${found_group}.yaml ]; then
        echo "group file ${group_file} not present"

        config_string=""
        for file in "$directory"/*; do
                if [ "$file" != "$directory/groups.out" ]; then
                        echo "file is $file"
                        if [ -f "$file" ]; then
                                config_string+=" --config=${file}"
                        fi
                fi
        done

        echo "Final config string:${config_string}"

        echo "lets see if it matches previous config string"
        current_line=$(grep -oP '^[^#]*(?<=OTELCOL_OPTIONS=").*(?=")"' /etc/otelcol-contrib/otelcol-contrib.conf)
        echo "current line is $current_line"
        current_config_string=$(echo "$current_line" | awk -F'"' '{print $2}')
        echo "current config line is ${current_config_string}"

        if [ "${config_string}" = "${current_config_string}" ]; then
                echo "config string looks good, nothing to do"
                exit 0
        else

                escaped_config_string=$(printf "%s\n" "${config_string}" | sed 's/[\&/]/\\&/g')
                sed -i "s/^OTELCOL_OPTIONS=.*$/OTELCOL_OPTIONS=\"${escaped_config_string}\"/" /etc/otelcol-contrib/otelcol-contrib.conf
                #chmod 777 /etc/otelcol-contrib/otelcol-contrib.conf

                exit 0
        fi
fi

otl_options_line=$(grep 'OTELCOL_OPTIONS=' /etc/otelcol-contrib/otelcol-contrib.conf)
echo $otl_options_line

if [[ "$otl_options_line" == *"${found_group}.yaml"* ]]; then
        echo "${found_group} found"
        echo "Group found in string and file exists we can exit here"
        exit 0
else
        echo "${found_group} not found in string"
        config_string=""
        for file in "$directory"/*; do
                if [ "$file" != "$directory/groups.out" ]; then
                        echo "file is $file"
                        if [ -f "$file" ]; then
                                config_string+=" --config=${file}"
                        fi
                fi
        done

        echo "Final config string:${config_string}"
        escaped_config_string=$(printf "%s\n" "${config_string}" | sed 's/[\&/]/\\&/g')
        sed -i "s/^OTELCOL_OPTIONS=.*$/OTELCOL_OPTIONS=\"${escaped_config_string}\"/" /etc/otelcol-contrib/otelcol-contrib.conf
        #chmod 777 /etc/otelcol-contrib/otelcol-contrib.conf

fi
