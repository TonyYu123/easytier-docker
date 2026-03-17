#!/bin/bash
# 处理Free配置
bash config-free.sh
# 提交 gist
node gist-upload script config
# 删除 config-cf 生成的文件
rm config/*_free.yaml
# 提交 github
git add -A
git commit -m "Standard Update"
git push
sleep 5
