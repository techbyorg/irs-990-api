Digital Ocean instructions

- option 1
- create 200gb volume to store xml on (faster than requesting from s3 individually)
- attach to a VM ($10 droplet is fine)
  - sudo apt-get update
  - sudo apt-get install awscli
  - aws configure
  - aws s3 sync s3://irs-form-990/ /path/to/mountedvolume
    - ctrl+z
    - disown -h %1
    - bg 1
    - started at 6:35
    - takes ~7 hr
- https://hub.docker.com/r/halverneus/static-file-server/
  - either run docker from the vm, or create a new kubernetes deployment w/ the disk
  - save snapshot of disk and delete disk (cheaper $$)

- have irs-990-api hit that docker since it's in same network (much faster than hitting s3)
