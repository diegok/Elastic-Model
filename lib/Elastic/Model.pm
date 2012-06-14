package Elastic::Model;

use Moose();
use Moose::Exporter();
use Carp;
use namespace::autoclean;

Moose::Exporter->setup_import_methods(
    class_metaroles => { class => ['Elastic::Model::Meta::Class::Model'] },
    with_meta       => [
        qw(has_namespace has_type_map override_classes
            has_analyzer has_tokenizer has_filter has_char_filter)
    ],
    base_class_roles => ['Elastic::Model::Role::Model'],
    also             => 'Moose',
);

#===================================
sub has_namespace {
#===================================
    my $meta   = shift;
    my $name   = shift or croak "No namespace name passed to namespace";
    my %params = ( types => @_ );

    my $types = $params{types};
    croak "No types specified for namespace $name"
        unless $types && %$types;

    $meta->add_namespace( $name => \%params );
}

#===================================
sub has_type_map { shift->set_class( 'type_map', @_ ) }
#===================================

#===================================
sub override_classes {
#===================================
    my $meta = shift;
    my %classes = ref $_[0] eq 'HASHREF' ? %{ shift() } : @_;
    for ( keys %classes ) {
        croak "Unknown arg for classes ($_)"
            unless $meta->get_class($_);
        $meta->set_class( $_ => $classes{$_} );
    }
}

#===================================
sub has_analyzer    { shift->add_analyzer( shift,    {@_} ) }
sub has_tokenizer   { shift->add_tokenizer( shift,   {@_} ) }
sub has_filter      { shift->add_filter( shift,      {@_} ) }
sub has_char_filter { shift->add_char_filter( shift, {@_} ) }
#==================================

1;

# ABSTRACT: A NoSQL object-persistence framework for Moose using ElasticSearch as a backend.

=head1 DESCRIPTION

Elastic::Model is a NoSQL object-persistence framework for Moose using
ElasticSearch as a backend.  It aims to Do the Right Thing with minimal
extra code, but allows you to benefit from the full power of ElasticSearch
as soon as you are ready to use it.

=head1 INTRODUCTION TO Elastic::Model

If you are not familiar with L<Elastic::Model>, you should start by reading
L<Elastic::Manual::Intro>.

The rest of the documentation on this page explains how to use the
L<Elastic::Model> module itself.

=head1 SYNOPSIS

    package MyApp;

    use Elastic::Model;

    has_namespace 'myapp' => {
        user => 'MyApp::User',
        post => 'MyApp::Post'
    };

    has_type_map 'MyApp::TypeMap';

    # Setup custom analyzers

    has_filter 'edge_ngrams' => (
        type     => 'edgeNGram',
        min_gram => 2,
        max_gram => 10
    );

    has_analyzer 'edge_ngrams' => (
        tokenizer => 'standard',
        filter    => [ 'standard', 'lowercase', 'edge_ngrams' ]
    );

    no Elastic::Model;


=cut

=head1 USING ELASTIC::MODEL

Your application needs a C<model> class to handle the relationship between
your object classes and the ElasticSearch cluster.

Your model class is most easily defined as follows:

    package MyApp;

    use Elastic::Model;

    has_namespace 'myapp' => {
        user => 'MyApp::User',
        post => 'MyApp::Post'
    };

    no Elastic::Model;

This applies L<Elastic::Model::Role::Model> to your C<MyApp> class,
L<Elastic::Model::Meta::Class::Model> to C<MyApp>'s metaclass and exports
functions which help you to configure your model.

Your model must define at least one L<namespace|Elastic::Manual::Terminology/Namespace>,
which tells Elastic::Model which
L<type|Elastic::Manual::Terminology/Type> (like a table in a DB) should be
handled by which of your classes.  So the above declaration says:

I<"For all L<indices|Elastic::Model::Terminology/Index> which belong to namespace
C<myapp>, objects of class C<MyApp::User> will be stored under the
L<type|Elastic::Model::Terminology/Type> C<user> in ElasticSearch.">

=head2 Custom TypeMap

Elastic::Model uses a L<TypeMap|Elastic::Model::TypeMap::Default> to figure
out how to inflate and deflate your objects, and how to configure them
in ElasticSearch.

You can specify your own TypeMap using:

    has_type_map 'MyApp::TypeMap';

See L<Elastic::Model::TypeMap::Base> for instructions on how to define
your own type-map classes.

=head2 Custom analyzers

Analysis is the process of converting full text into C<terms> or C<tokens> and
is one of the things that gives full text search its power.  When storing text
in the ElasticSearch index, the text is first analyzed into terms/tokens.
Then, when searching, search keywords go through the same analysis process
to produce the terms/tokens which are then searched for in the index.

Choosing the right analyzer for each field gives you enormous control over
how your data can be queried.

There are a large number of built-in analyzers available, but frequently
you will want to define custom analyzers, which consist of:

=over

=item *

zero or more character filters

=item *

a tokenizer

=item *

zero or more token filters

=back

L<Elastic::Model> provides sugar to make it easy to specify custom analyzers:

=head3 has_char_filter

Character filters can change the text before it gets tokenized, for instance:

    has_char_filter 'my_mapping' => (
        type        => 'mapping',
        mappings    => ['ph=>f','qu=>q']
    );

=head3 has_tokenizer

A tokenizer breaks up the text into individual tokens or terms. For instance,
the C<pattern> tokenizer could be used to split text using a regex:

    has_tokenizer 'my_word_tokenizer' => (
        type        => 'pattern',
        pattern     => '\W+',          # splits on non-word chars
    );

=head3 has_filter

Any terms/tokens produced by the L</"tokenizer"> can the be passed through
multiple token filters.  For instance, each term could be broken down into
"edge ngrams" (eg 'foo' => 'f','fo','foo') for partial matching.

    has_filter 'my_ngrams' => (
        type        => 'edgeNGram',
        min_gram    => 1,
        max_gram    => 10,
    );

=head3 has_analyzer

Custom analyzers can be defined by combining character filters, a tokenizer and
token filters, some of which could be built-in, and some defined by the
keywords above.

For instance:

    has_analyzer 'partial_word_analyzer' => (
        type        => 'custom',
        char_filter => ['my_mapping'],
        tokenizer   => ['my_word_tokenizer'],
        filter      => ['lowercase','stop','my_ngrams']
    );

=head2 Overriding Core Classes

If you would like to override any of the core classes used by L<Elastic::Model>,
then you can do so as follows:

    override_classes (
        domain  => 'MyApp::Domain',
        store   => 'MyApp::Store'
    );

The defaults are:

=over

=item *

C<namespace> C<-----------> L<Elastic::Model::Namespace>

=item *

C<domain> C<--------------> L<Elastic::Model::Domain>

=item *

C<store> C<---------------> L<Elastic::Model::Store>

=item *

C<view> C<----------------> L<Elastic::Model::View>

=item *

C<scope> C<---------------> L<Elastic::Model::Scope>

=item *

C<results> C<-------------> L<Elastic::Model::Results>

=item *

C<scrolled_results> C<----> L<Elastic::Model::Results::Scrolled>

=item *

C<result> C<--------------> L<Elastic::Model::Result>

=back

=head1 SEE ALSO

=over

=item *

L<Elastic::Manual>

=item *

L<Elastic::Doc>

=back