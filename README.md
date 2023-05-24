On a CS9 system:
```bash
bash bootstrap_script.sh && \
bash list_requirements.sh && \
grep delorean dependencies  | awk '{print $1}' | sort | uniq > packages_to_build_in_epel
```


bugzilla info -c "Fedora EPEL" --active-components > ~/workspace/openstackclient-epel9/fedora_epel9_active-components
