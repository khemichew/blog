hugo
#update links
cd public || exit
find . -name "index.html" -type f -exec sed -i 's/href="\//href="\/~kjc20\//g' {} \; \
-exec sed -i 's/src="\//src="\/~kjc20\//g' {} \;
find public -name "404.html" -type f -exec sed -i 's/href="\//href="\/~kjc20\//g' {} \;
# Sublink: ~kjc20
rm blog.zip
zip -r blog.zip .
scp blog.zip kjc20@sftp.doc.ic.ac.uk:~/