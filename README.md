elb_update_cert
===

#### Document

* [**A cron job to (re-)issue server certificate of Let's Encrypt and update ELB's certificate on Amazon Linux**](http://blog.xn--nyqr7s4vc72p.com/2016/01/a-script-to-re-issue-server-certificate.html)


#### Setup Amazon Linux host

```bash
sudo yum update
sudo yum install -y git nginx libffi-devel puppet libffi-devel puppet httpd24 jq
sudo /etc/init.d/nginx start
sudo chkconfig nginx on
```


#### Execute

1. Add AWS user as `example.iam_policy.json`
1. Configure nginx as `etc/nginx/nginx.conf` and restart nginx
1. Edit `elb_update_cert.sh` to modify `__VALIABLES__` as yours
1. Execute commands below and confirm everything fine
1. Add cron job as `etc/cron.d/elb_update_cert`

```bash
git clone https://github.com/letsencrypt/letsencrypt /home/ec2-user/letsencrypt
sudo aws configure --profile elb_update_cert
sudo bash elb_update_cert.sh
```

cf. http://qiita.com/hidekuro/items/482520f220a305dc147b
