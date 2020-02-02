# wget http://validator.w3.org/validator.tar.gz
# wget http://validator.w3.org/sgml-lib.tar.gz
# wget http://validator.w3.org/index.html

tar -zxf validator.tar.gz -C ${SRC_DIR}
tar -zxf sgml-lib.tar.gz -C ${SRC_DIR}
cp val-index.html ${SRC_DIR}

# Prepare w3c-markup-validator 1.3.
# NOTE: This is much more complicated than these instructions make it
# look.  For the full story, see the `w3c-validator' info file.
ln -s validator.conf.diff ${SRC_DIR}/validator.conf.diff
(
    cd ${SRC_DIR}
    mv validator-1.1/htdocs/sgml-lib/ validator-1.3/htdocs/
    cd validator-1.3/htdocs/config
    cp -p validator.conf validator.conf.old
    patch -p1 validator.conf ../../../validator.conf.diff
    rm ../../../validator.conf.diff
    cat > w3c-markup-validator-apache2.conf <<EOF
ScriptAlias /w3c-markup-validator/check ${PREFIX}/share/w3c-markup-validator/cgi-bin/check
Alias /w3c-markup-validator ${PREFIX}/share/w3c-markup-validator/htdocs
<Location /w3c-markup-validator>
  Options +Includes +MultiViews
  AddOutputFilter INCLUDES .html
  Order allow,deny
  Allow from all
</Location>
EOF
    cd ..
    mv index.html index.html.old
)
cp ${SRC_DIR}/val-index.html ${SRC_DIR}/validator-1.3/htdocs/index.html
# NOTE: We only need to make this change because our server apparently
# isn't setup to server JavaScript files withou an extension.
sed -i -e 's|scripts/combined|scripts/combined.js|g' \
  ${SRC_DIR}/validator-1.3/htdocs/index.html
