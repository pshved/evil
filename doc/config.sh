#!/bin/bash
pth=/home/pavel/work/zlo
export PATH=$pth/lib/ruby/gems/1.9.1/gems/bin:$pth/bin:$PATH
export GEM_PATH=$pth/lib/ruby/gems/1.9.1
# is is needed?
export GEM_ROOT=$pth/lib/ruby/gems/1.9.1
# should be one level deeper
export GEM_HOME=$pth/lib/ruby/gems/1.9.1/gems
export RUBYOPT=''
alias gi='gem install --install-dir='$pth'/lib/ruby/gems/1.9.1 --bindir='$pth'/bin --env-shebang'

