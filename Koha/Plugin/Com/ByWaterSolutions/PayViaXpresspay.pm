package Koha::Plugin::Com::ByWaterSolutions::PayViaXpresspay;

use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Auth;
use Koha::Account;
use Koha::Account::Lines;
use URI::Escape qw(uri_unescape);
use LWP::UserAgent;
use JSON qw(from_json);

## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name          => 'Pay Via Xpresspay',
    author        => 'Kyle M Hall',
    description   => 'This plugin enables online OPAC fee payments via Xpresspay',
    date_authored => '2018-11-27',
    date_updated  => '1900-01-01',
    minimum_version => '18.00.00.000',
    maximum_version => undef,
    version         => $VERSION,
};

our $ENABLE_DEBUGGING = 1;

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub opac_online_payment {
    my ( $self, $args ) = @_;

    return $self->retrieve_data('enable_opac_payments') eq 'Yes';
}

sub opac_online_payment_begin {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my ( $template, $borrowernumber ) = get_template_and_user(
        {
            template_name   => $self->mbf_path('opac_online_payment_begin.tt'),
            query           => $cgi,
            type            => 'opac',
            authnotrequired => 0,
            is_plugin       => 1,
        }
    );

    my @accountline_ids = $cgi->multi_param('accountline');

    my $rs = Koha::Database->new()->schema()->resultset('Accountline');
    my @accountlines = map { $rs->find($_) } @accountline_ids;

    my $token = "B" . $borrowernumber . "T" . time;
    C4::Context->dbh->do(
        q{
		INSERT INTO xpresspay_plugin_tokens ( token, borrowernumber )
        VALUES ( ?, ? )
	}, undef, $token, $borrowernumber
    );

    $template->param(
        borrower             => scalar Koha::Patrons->find($borrowernumber),
        payment_method       => scalar $cgi->param('payment_method'),
        enable_opac_payments => $self->retrieve_data('enable_opac_payments'),
        XpresspayPostUrl        => $self->retrieve_data('XpresspayPostUrl'),
        XpresspayMerchantCode   => $self->retrieve_data('XpresspayMerchantCode'),
        XpresspaySettleCode     => $self->retrieve_data('XpresspaySettleCode'),
        XpresspayApiUrl         => $self->retrieve_data('XpresspayApiUrl'),
        XpresspayApiPassword    => $self->retrieve_data('XpresspayApiPassword'),
        accountlines         => \@accountlines,
        token                => $token,
    );

    print $cgi->header();
    print $template->output();
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template( { file => 'configure.tt' } );

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            enable_opac_payments =>
              $self->retrieve_data('enable_opac_payments'),
            XpresspayPostUrl      => $self->retrieve_data('XpresspayPostUrl'),
            XpresspayMerchantCode => $self->retrieve_data('XpresspayMerchantCode'),
            XpresspaySettleCode   => $self->retrieve_data('XpresspaySettleCode'),
            XpresspayApiUrl       => $self->retrieve_data('XpresspayApiUrl'),
            XpresspayApiPassword  => $self->retrieve_data('XpresspayApiPassword'),
        );

        print $cgi->header();
        print $template->output();
    }
    else {
        $self->store_data(
            {
                enable_opac_payments => $cgi->param('enable_opac_payments'),
                XpresspayPostUrl        => $cgi->param('XpresspayPostUrl'),
                XpresspayMerchantCode   => $cgi->param('XpresspayMerchantCode'),
                XpresspaySettleCode     => $cgi->param('XpresspaySettleCode'),
                XpresspayApiUrl         => $cgi->param('XpresspayApiUrl'),
                XpresspayApiPassword    => $cgi->param('XpresspayApiPassword'),
            }
        );
        $self->go_home();
    }
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return 'xpresspay';
}

sub install() {
    return 1;
}

sub uninstall() {
    return 1;
}

1;
