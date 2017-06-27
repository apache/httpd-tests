# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
package Misc;

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil;
use Apache::TestConfig ();

use strict;
use warnings FATAL => 'all';
require IO::Select;

BEGIN {
    # Just a bunch of useful subs
}

sub do_do_run_run
{
    my $msg = shift;
    my $func = shift;

    pipe(READ_END, WRITE_END);
    my $pid = fork();
    unless (defined $pid) {
        t_debug "couldn't fork $msg";
        ok 0;
        exit;
    }
    if ($pid == 0) {
        print WRITE_END 'x';
        close WRITE_END;
        $func->(@_);
        exit;
    }
    # give time for the system call to take effect
    unless (IO::Select->new((\*READ_END,))->can_read(2)) {
        t_debug "timed out waiting for $msg";
        ok 0;
        kill 'TERM', $pid;
        exit;
    }
    return $pid;
}


1;
__END__
