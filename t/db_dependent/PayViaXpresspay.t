#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 1;

use C4::Context;
use Koha::Database;

use t::lib::TestBuilder;

use Koha::Plugin::Com::ByWaterSolutions::PayViaXpresspay;

my $schema = Koha::Database->new->schema;

my $plugin = Koha::Plugin::Com::ByWaterSolutions::PayViaXpresspay->new( { enable_plugins => 1 } );

subtest 'cronjob_nightly() removes only abandoned tokens' => sub {
    plan tests => 3;
    $schema->storage->txn_begin;

    my $builder = t::lib::TestBuilder->new;
    my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );

    my $dbh = C4::Context->dbh;
    $dbh->do(
        q{INSERT INTO xpresspay_plugin_tokens ( token, borrowernumber, created_on ) VALUES ( ?, ?, DATE_SUB(NOW(), INTERVAL 8 DAY) )},
        undef, 'stale-token', $patron->borrowernumber
    );
    $dbh->do(
        q{INSERT INTO xpresspay_plugin_tokens ( token, borrowernumber, created_on ) VALUES ( ?, ?, NOW() )},
        undef, 'fresh-token', $patron->borrowernumber
    );

    $plugin->cronjob_nightly;

    my $count = sub {
        $dbh->selectrow_array( q{SELECT COUNT(*) FROM xpresspay_plugin_tokens WHERE token = ?}, undef, $_[0] );
    };
    is( $count->('stale-token'), 0, 'a week-old token from an abandoned checkout is removed' );
    is( $count->('fresh-token'), 1, 'a current token is left alone' );

    $plugin->cronjob_nightly;
    is( $count->('fresh-token'), 1, 'running the job again changes nothing' );

    $schema->storage->txn_rollback;
};
