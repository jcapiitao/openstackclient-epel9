On a CS9 system:
```bash
bash bootstrap_script.sh
bash list_requirements.sh
grep delorean dependencies  | awk '{print $1}' | sort | uniq > packages_to_build_in_epel
```
