#!/bin/bash

cd ~/leseco-pmagic/leseco_automatic_pkg/

echo "Creating txz"
tar cvJf ~/pmagic_staging/pmagic_leseco_auto/modules/leseco_auto.txz *

cd ~/pmagic_staging/pmagic_leseco_auto/

echo "Creating cgz"
find . | cpio --quiet -H newc -o | gzip -9 > /tftpboot/er/plugins/pmagic/leseco_auto.cgz

echo "Done."

