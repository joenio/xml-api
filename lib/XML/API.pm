# ----------------------------------------------------------------------
# Copyright (C) 2004-2006 Mark Lawrence <nomad@null.net>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# ----------------------------------------------------------------------
# XML::API::Element - Visible representation of an XML element
#
# This is a private package (not to be used outside XML::API)
# ----------------------------------------------------------------------
package XML::API::Element;
use strict;
use warnings;
use Carp;
use overload '""' => \&_as_string, 'fallback' => 1;

our $VERSION = '0.15';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %param = (
        element   => undef,
        attrs     => {},
        content   => undef,
        @_
    );

    croak 'element not defined' unless(defined($param{element}));
    croak 'attrs not defined'   unless(defined($param{attrs}));

    my $self = \%param;
    bless ($self, $class);
    return $self;
}

sub attrs_as_string {
    my $self = shift;
    my @strings;

    foreach my $key (sort keys %{$self->{attrs}}) {
        my $val = $self->{attrs}->{$key};
        if (!defined($val)) {
            warn "Attribute '$key' (element '$self->{element}') is undefined";
            $val = '*undef*';
        }
        push(@strings, qq{$key="$val"});
    }

    return ' ' . join(' ', @strings) if (@strings);
    return '';
}

# the opening tag for an element with element-type children
sub eopen {
    my $self = shift;
    return '<'. $self->{element} . $self->attrs_as_string .'>'.
            (defined($self->{content}) ? $self->{content} : '');
}

# the opening tag for an element with no element-type children
sub eopen_single {
    my $self = shift;
    return '<'. $self->{element} . $self->attrs_as_string .' />' unless(defined($self->{content}));
    return '<'. $self->{element} . $self->attrs_as_string .'>'.
            (defined($self->{content}) ? $self->{content} : '') .
            '</'. $self->{element} .'>';
}

sub eclose {
    my $self = shift;
    return '</'. $self->{element} .'>';
}

sub eclose_single {
}

sub _as_string {
    my $self = shift;
    return $self->{element} || '*empty*';
}

# ----------------------------------------------------------------------
# XML::API::Element::Comment -  representation of an XML comment
#
# This is a private package (not to be used outside XML::API)
# ----------------------------------------------------------------------
package XML::API::Element::Comment;
use strict;
use warnings;
use Carp;
use base 'XML::API::Element';
use overload '""' => \&_as_string, 'fallback' => 1;

our $VERSION = '0.15';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %param = (
        content   => undef,
        @_
    );

    croak 'content not defined' unless(defined($param{content}));

    $param{content} =~ s/--/- -/g;
    my $self = \%param;
    bless ($self, $class);
    return $self;
}

sub eopen {
    my $self = shift;
    return "<!-- $self->{content} -->";
}

sub eopen_single {
    my $self = shift;
    return $self->eopen;
}

sub eclose {
}

sub eclose_single {
}

sub _as_string {
    my $self = shift;
    return '*comment* '. $self->{content};
}

# ----------------------------------------------------------------------
# XML::API::Element::Cdata -  representation of XML CDATA
#
# This is a private package (not to be used outside XML::API)
# ----------------------------------------------------------------------
package XML::API::Element::Cdata;
use strict;
use warnings;
use Carp;
use base 'XML::API::Element';
use overload '""' => \&_as_string, 'fallback' => 1;

our $VERSION = '0.15';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %param = (
        content   => undef,
        @_
    );

    croak 'content not defined' unless(defined($param{content}));

    my $self = \%param;
    bless ($self, $class);
    return $self;
}

sub eopen {
    my $self = shift;
    return '<![CDATA['. $self->{content} . ']]>';
}

sub eopen_single {
    my $self = shift;
    return $self->eopen;
}

sub eclose {
}

sub eclose_single {
}

sub _as_string {
    my $self = shift;
    return '*cdata* '. $self->{content};
}

# ----------------------------------------------------------------------
# XML::API - Perl extension for creating XML documents
# ----------------------------------------------------------------------
package XML::API;
use strict;
use warnings;
use Carp qw(cluck carp croak confess);
use Scalar::Util qw/blessed/;
use XML::Parser::Expat;
use Tree::Simple;
use overload '""' => \&_as_string, 'fallback' => 1;

our $VERSION          = '0.15';
our $DEFAULT_ENCODING = 'UTF-8';
our $ENCODING         = undef;
our $Indent           = '  ';
our $AUTOLOAD;

my $string;
my %parsers;


=head1 NAME

XML::API - Perl extension for writing XML

=head1 VERSION

0.15

=head1 SYNOPSIS

  use XML::API;
  my $x = XML::API->new(doctype => 'xhtml');
  $x->_comment('My --First-- XML::API document');
  
  $x->html_open();
  $x->head_open();
  $x->title('Test Page');
  $x->head_close();
  $x->body_open();
  $x->div_open(-id => 'content');
  $x->p(-class => 'test', 'Some <<odd>> input');
  $x->p(-class => 'test', '& some other &stuff;');
  $x->div_close();
  $x->body_close();
  $x->html_close();

  $x->_print;

Will produce this nice output:

  <?xml version="1.0" encoding="UTF-8" ?>
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict...>
  <!-- My - -First- - XML::API document -->
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Test Page</title>
    </head>
    <body>
      <div id="content">
        <p class="test">Some &lt;&lt;odd&gt;&gt; input</p>
        <p class="test">&amp; some other &stuff;</p>
      </div>
    </body>
  </html>

=head1 DESCRIPTION

B<XML::API> is a class for creating XML documents using
object method calls. This class is meant for generating XML
programatically and not for reading or parsing it.

A document author calls the desired methods (representing elements) to
create an XML tree in memory which can then be rendered or saved as desired.
The advantage of having the in-memory tree is that you can be very flexible
about when different parts of the document are created and the final output
is always nicely rendered.

=head1 TUTORIAL

The first step is to create an object. The 'doctype' attribute is
mandatory. Known values (ie - distributed with XML::API) are 'xhtml'
and 'rss'. The encoding is not mandatory and will default to 'UTF-8'.

  use XML::API;
  my $x = XML::API->new(doctype => 'xhtml', encoding => 'UTF-8');

$x is the only object we need for our entire XHTML document. It starts
out empty so we want to open up the html element:

  $x->html_open;

Because we have called a *_open() function the 'current' or 'containing'
element is now 'html'. All further elements will be added inside the
'html' element. So lets add head and title elements and the title content
('Document Title') to our object:

  $x->head_open;
  $x->title('Document Title');

The 'title()' method on its own (ie not 'title_open()') indicates that we
are specifiying the entire title element. Further method calls will
continue to place elements inside the 'head' element until we specifiy we
want to move on by calling the _close method:

  $x->head_close();

This sets the current element back to 'html'.

So, basic elements seem relatively easy. How do we create elements with
attributes? When either the element() or element_open() methods are called
with a hashref argument the keys and values of the hashref become the
attributes:

  $x->body_open({id => 'bodyid'}, 'Content', 'more content');

or if you want, you can also use CGI-style attributes which I prefer
because it takes less typing:

  $x->body_open(-id => 'bodyid', 'Content', 'more content');

By the way, both the element() and element_open() methods take arbitrary
numbers of content arguments as shown above. However if you don't want to
specify the content of the element at the time you open it up you can
use the _add() utility method later on:

  $x->div_open();
  $x->_add('Content added after the _open');

The final thing is to close out the elements and render the docment.

  $x->div_close();
  $x->body_close();
  print $x->_as_string();

Because we are not adding any more elements or content it is not strictly
necessary to close out all elements, but consider it good practice.

You can add XML::API object to other objects, which lets you create for
instance the head and body parts separately, and just bring them all
together just before printing:

  my $h = XML::API::XHTML->new();
  $h->head_open
  ...
  my $x = XML::API::XHTML->new();
  $x->html_open;
  $x->_add($h);
  $x->html_close;
  $x->_print;

Note that it is also possible to call the XML::API::<doctype> class directly.

=head1 CLASS SUBROUTINES

=head2 new

Create a new XML::API based object. The object is initialized as empty
(ie contains no elements). Takes the following optional arguments:

  doctype  => '(xhtml|rss|WIX2)'
  encoding => 'xxx'
  debug    => 1|0

If a valid (ie known to XML::API) doctype is given then an object of class
XML::API::DOCTYPE will be returned instead. This method will die if doctype is
unknown. You can also call XML::API::DOCTYPE->new() directly.

For the effects of the encoding and debug parameters see the
documentation for '_encoding' and '_debug' below.

=cut

# Not implemented yet:
#  strict   => 0|1                # Optional, defaults to 0
#By default strict checking is performed to make sure that the structure
#of the document matches the Schema. This can be turned off by setting
#'strict' to false (0 or undef).

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = {
        doctype   => undef,
        encoding  => undef,
        debug     => undef,
        @_,
    };

    #
    # Derived classes
    #
    if ($class ne __PACKAGE__) {
        if ($self->{doctype}) {
            confess("Must not specify doctype when instantiating $class");
        }
    }
    elsif ($self->{doctype}) {
        $class = $class . '::' . uc($self->{doctype});
        if (! eval "require $class;1;") {
            die "Could not load module '$class'";
        }
    }
    delete $self->{doctype};
    bless ($self, $class);

    $self->{encoding} = $self->{encoding} || $ENCODING || $DEFAULT_ENCODING;
    $self->{trees}    = undef;
    $self->{current}  = undef;
    $self->{string}   = undef;
    $self->{ids}      = {};
    $self->{langs}    = {};

    return $self;
}


#
# These should be overridden by derived classes
#
#sub _xsd {
#    my $self = shift;
#    return undef;
#}

sub _root_element {
    return '';
}

sub _root_attrs {
    return {};
}

sub _doctype {
    return '';
}


=head1 CONTENT

=head2 $x->element_open(-attribute => $value, {attr2 => 'val2'}, $content)

Add a new element to the 'current' element, and set the current element
to be the element just created. Returns a reference (private data type)
to the new element which can be used in the _goto function below.

Ie given that $x currently represents:

  <html>  <---- 'current' element
          <---- future elements/content goes here
  </html>

then $x->head_open(-attribute => $value) means the tree is now:

  <html>
    <head attribute="$value">  <---- 'current' element
                               <---- future elements/content goes here
    </head>
  </html>

=head2 $x->_add($content)

Add $content to the 'current' element. $content can be either scalar
(in which case the characters '<&">' will be escaped)
or another XML::API object. This method will carp if you
attempt to add $x to itself or if $x does not contain any elements
or if $content does not contain any elements.

=cut

sub _add {
    my $self = shift;
    foreach my $item (@_) {
        if (blessed($item) and $item->isa(__PACKAGE__)) {
            if (\$item == \$self) {
                die 'Cannot _add object to itself';
            }
            if (!$item->{trees}) {
                carp "failed to _add object with no elements";
                return;
            }
            if (!$self->{current}) {
                push(@{$self->{trees}}, @{$item->{trees}});
            }
            else {
                $self->{current}->addChildren(@{$item->{trees}});
            }
            foreach my $lang (keys %{$item->{langs}}) {
                $self->{langs}->{$lang} = 1;
            }
        }
        else {
            if ($self->{current}) {
                my $t = Tree::Simple->new(ref($item) ? $item :
                                            _escapeXML($item));
                $self->{current}->addChild($t);
            }
            else {
                croak('Cannot use _add with no current element');
            }
        }
    }
}

=head2 $x->_raw($content)

Adds unescaped content to the 'current' element. You need to be careful
of characters that mean something in XML such as '<','&' and '>'.
This method will die if $content is an XML::API derivative or if
$x does not have a current element.

=cut

sub _raw {
    my $self = shift;
    foreach my $item (@_) {
        if (ref($item) and $item->isa(__PACKAGE__)) {
            croak('Cannot add XML::API objects as raw');
        }
        elsif (!$self->{current}) {
            croak('Cannot use _raw outside of an element');
        }

        my $t = Tree::Simple->new($item);
        $self->{current}->addChild($t);
    }
}


=head2 $x->element_close( )

This does not actually modify the tree but simply tells the object that
future elements will be added to the parent of the current element.
Ie given that $x currently represents:

  <div>
    <p>  <---- 'current' element
      $content
           <---- future elements/content goes here
    </p>
  </div>

then $x->p_close() means the tree is now:

  <div>    <---- 'current' element
    <p>
      $content
    </p>
           <---- future elements go here
  </div>

If you try to call a _close() method that doesn't match the current
element a warning will be issued and the call will fail.


=head2 $x->element(-attribute => $value, {attr2 => 'val2'}, $content)

Add a new element to the 'current' element but keep the 'current'
element the same. Returns a reference (private data type)
to the new element which can be used in the _goto function below.

This is effectively the same as the following:

    $x->element_open(-attribute => $value, -attr2=>'val2');
    $x->_add($content);
    $x->element_close;

If $content is not given (or never added with the _add method) for
an element then it will be rendered as empty. Ie, $x->br() produces:

    <br />

=cut

#
# The implementation for element, element_open and element_close
#

sub AUTOLOAD {
    my $self = shift;
    my $element = $AUTOLOAD;

    my ($open, $close) = (0,0);

    if ($element =~ s/.*::(.*)_open$/$1/) {
          $open = 1;  
    }
    elsif ($element =~ s/.*::(.*)_close$/$1/) {
          $close = 1;  
    }
    else  {
        $element =~ s/.*:://;
    }

    croak 'element not defined' unless($element);

    if ($element =~ /^_/) {
        croak "Undefined subroutine &" . ref($self) . "::$element called";
        return undef;
    }

    # reset the output string in case it has been cached
    $self->{string} = undef;

    if ($element eq $self->_root_element) {
        $self->{has_root_element} = 1;
    }

    my $attrs = {};
    my @content;

    my $total = scalar(@_) - 1;
    my $next;

    foreach my $i (0..$total) {
        if ($next) {
            $next = undef;
            next;
        }

        my $arg  = $_[$i];
        if (ref($arg) eq 'HASH') {
            while (my ($key,$val) = each %$arg) {
                $attrs->{$key} = $val;
                if (!defined($val)) {
                    carp "attribute '$key' undefined (element '$element')";
                    $attrs->{$key} = ''
                }
            }
        }
        elsif (defined($arg) and $arg =~ m/^-.+/) {
            $arg =~ s/^-//;
            $attrs->{$arg} = $_[++$i];
            if (!defined($attrs->{$arg})) {
                carp "attribute '$arg' undefined (element '$element') ";
                $attrs->{$arg} = ''
            }
            $next = 1;
            next;
        }
        else {
            push(@content, defined($arg) ? _escapeXML($arg) : '');
        }
    }

    #
    # Start with the default root element attributes and add those
    # given if this is the root element
    #
    if ($element eq $self->_root_element) {
        my $rootattrs = $self->_root_attrs;
        while (my ($key,$val) = each %$attrs) {
            $rootattrs->{$key} = $val;
        }
        $attrs = $rootattrs;
    }

    my ($file,$line) = (caller)[1,2] if($self->{debug});

    if ($close) {
        if (!$self->{current}) {
            carp 'attempt to close non-existent element "' . $element . '"';
            return;
        }
        my $cur = $self->{current}->getNodeValue;
        if ($element eq $cur->{element}) {
            if (!$self->{current}->isRoot) {
                $self->{current} = $self->{current}->getParent();
                $self->_comment("DEBUG: '$element' close at $file:$line") if($self->{debug});
                return;
            }
            else {
                $self->{current} = undef;
                return;
            }
        }
        else {
            carp 'attempted to close element "' . $element . '" when current ' .
                 'element is "' . $cur->{element} . '"';
            return;
        }
    }

    #
    # Either element() or element_open()
    #
    if ($self->{langnext}) {
        $attrs->{'xml:lang'} = delete $self->{langnext};
    }

    my $e = XML::API::Element->new(element => $element,
                              attrs   => $attrs,
                              content => @content ?
                                         join('', @content) : undef);
    my $t = Tree::Simple->new($e);

    if ($self->{current}) {
        $self->{current}->addChild($t);
    }
    else {
        push(@{$self->{trees}}, $t);
    }

    if ($open) {
        $self->{current} = $t;
    }

    $self->_comment("DEBUG: '$element' (open) at $file:$line")
        if($self->{debug});

    return $e;
}


=head2 $x->_comment($comment)

Add an XML comment to $x. Is almost the same as this:

    $x->_raw("\n<!--");
    $x->_raw($content);
    $x->_raw('-->')

Except that indentation is correct. Any occurences of '--' in $content
will be replaced with '- -'.

=cut

sub _comment {
    my $self = shift;
    my $c = XML::API::Element::Comment->new(content => join('',@_)); # FIXME: should escape?
    my $t = Tree::Simple->new($c);

    if (!$self->{current}) {
        push(@{$self->{trees}}, $t);
    }
    else {
        $self->{current}->addChild($t);
    }
    $self->{string} = undef;
}

=head2 $x->_cdata($content)

A shortcut for $x->_raw("\n<![CDATA[", $content, " ]]>");

=cut

sub _cdata {
    my $self = shift;
    my $e = XML::API::Element::Cdata->new(content => join('',@_));
    my $t = Tree::Simple->new($e);

    if (!$self->{current}) {
        push(@{$self->{trees}}, $t);
    }
    else {
        $self->{current}->addChild($t);
    }

    $self->{string} = undef;
}


=head2 $x->_javascript($script )

A shortcut for adding $script inside a pair of
<script type="text/javascript"> elements and a _CDATA tag.

=cut

sub _javascript {
    my $self = shift;
    $self->script_open(-type => 'text/javascript');
    $self->_raw("// -------- JavaScript Begin -------- <![CDATA[\n");
    $self->_raw(@_);
    $self->_raw("// --------- JavaScript End --------- ]]>");
    $self->script_close;
    return;
}


=head2 $x->_parse($content)

Adds content to the current element, but will parse it for xml elements
and add them as method calls. Regardless of $content (missing end tags etc)
the current element will remain the same.

Make sure that your encoding is correct before making this call as
it will be passed as such to XML::Parser::Expat.

=cut

#
# Start Element handler for _parse
#
sub _sh {
    my ($p, $el, %atts) = @_;
    my $self = $parsers{$p};
    if (!$self) {
        warn 'Parser not found!!';
        return;
    }
    my $f = $el . '_open';
    $self->$f(\%atts);
}

#
# Content handler for _parse
#
sub _ch {
    my ($p, $str) = @_;
    my $self = $parsers{$p};
    if (!$self) {
        warn 'Parser not found!!';
        return;
    }

    $self->_add($str);
}

#
# End Element handler for _parse
#
sub _eh {
    my ($p, $el) = @_;
    my $self = $parsers{$p};
    if (!$self) {
        warn 'Parser not found!!';
        return;
    }
    my $f = $el . '_close';
    $self->$f();
}

sub _parse {
    my $self = shift;
    my $current = $self->{current};

    foreach (@_) {
        next unless(defined($_));
        my $parser = new XML::Parser::Expat(ProtocolEncoding =>
                                               $self->{encoding});
        $parsers{$parser} = $self;

        $parser->setHandlers('Start' => \&_sh,
                             'Char'  => \&_ch,
                             'End'   => \&_eh);
        if (!eval {$parser->parse($_);1;}) {
            warn $@;
        }
        $parser->release;
        delete $parsers{$parser};
    }

    # always make sure that we finish where we started
    $self->{current} = $current;
}


=head2 $x->_attrs( )

Allows you to get/set the attributes of the current element. Accepts
and returns and hashref.

=cut

sub _attrs {
    my $self  = shift;

    if (@_) {
        my $attrs = shift;
        if (!$attrs or ref($attrs) ne 'HASH') {
            croak 'usage: _attrs($hashref)';
        }
        $self->{current}->getNodeValue()->{attrs} = $attrs;
    }
    return $self->{current}->getNodeValue->{attrs};
}

=head1 META DATA

=head2 $x->_encoding($value)

Set the encoding definition produced in the xml declaration. Returns
the current value if called without an argument.
This is an alternative to defining the encoding in the call to 'new'.

The XML encoding definition for objects is determined by the
following, in this order:

  * the last call to _encoding
  * the encoding parameter given at object creation
  * $XML::API::ENCODING, set by your script before calling new
  * UTF-8, the package default

If you _add one object to another with different encodings the
top-level object's definition will be used.

=cut

sub _encoding {
    my $self = shift;
    if (@_) {
        $self->{encoding} = shift;
    }
    return $self->{encoding};
}


=head2 $x->_set_lang($lang)

Add an 'xml:lang' attribute to the next element to be created. In
terms of output created this means that:

  $x->_set_lang('de');
  $x->p('Was sagst du?');

is equivalent to:

  $x->p(-xml:lang => 'de', 'Was sagst du?');

with the added difference that _set_lang keeps track of each call
and the list of languages set can be retrieved using the _langs
method below.

The first time _set_lang is called the xml:lang attribute will be
added to the root element instead of the next one, unless $x is
a generic XML document. Without a XML::API::<class> object we
don't know if we have the root element or not.

=cut


sub _set_lang {
    my $self = shift;
    my $lang = shift || croak 'usage: set_lang($lang)';

    if (ref($self) eq __PACKAGE__ or $self->{langroot}) {
        $self->{langnext} = $lang;
    }
    else {
        $self->{langroot} = $lang;
    }
    $self->{langs}->{$lang} = 1;

    return;
}


=head2 $x->_langs

Returns the list of the languages that have been specified by _set_lang.

=cut

sub _langs {
    my $self = shift;
    return keys %{$self->{langs}};
}


=head2 $x->_debug(1|0)

Turn on|off debugging from this point onwards. Debugging appears as
xml comments in the rendered XML output.

=cut

sub _debug {
    my $self = shift;
    if (@_) {
        $self->{debug} = shift;
    }
    return $self->{debug};
}



=head2 $x->_current( )

Returns a reference (private data type) to the current element. Can
be used in the _goto method to get back to the current element in the
future.

=cut

sub _current {
    my $self = shift;
    return $self->{current};
}

=head2 $x->_set_id($id)

Set an identifier for the current element. You can then use the value
of $id in the _goto() method.

=cut

sub _set_id {
    my $self = shift;
    my $id   = shift;

    if (!defined($id) or $id eq '') {
        carp '_set_id called without a valid id';
        return;
    }
    if (defined($self->{ids}->{$id})) {
        carp 'id '.$id.' already defined - overwriting';
    }
    $self->{ids}->{$id} = $self->{current};
}

=head2 $x->_goto($id)

Change the 'current' element. $id is a value which has been previously
used in the _set_id() method, or the return value of a _current() call.

This is useful if you create the basic structure of your document, but
then later want to go back and modify it or fill in the details.

=cut

sub _goto {
    my $self = shift;

    if (@_) {
        my $id = shift;
        if (!defined $id) {
#            carp "undefined argument given to _goto";
            $self->{current} = undef;
            return;
        }
        if (ref($id) and $id->isa('Tree::Simple')) {
            $self->{current} = $id;
        }
        elsif (defined($self->{ids}->{$id})) {
                $self->{current} = $self->{ids}->{$id};
        }
        else {
            carp "Nonexistent ID given to _goto: '$id'. ",
                 "(Known IDs: ", join(',',keys(%{$self->{ids}})),')';
            $self->{current} = undef;
        }
    }
    return $self->{current};
}


=head1 OUTPUT

=head2 $x->_as_string( )

Returns the xml-rendered version of the object. If $x has the root
element for the doctype, or if $x is a pure XML::API object then the
string is prefixed by the XML declaration (with the encoding as
defined in the '_encoding' method documentation):

  <?xml version="1.0" encoding="UTF-8" ?>

The xml is cached unless the object is modified so _as_string can be
called mulitple times in a row with little cost.

=cut

sub _child_next_sib_is_element {
    my $i = shift;
    # if our first child is an element....
    if ($i->getChildCount and my $cv = $i->getChild(0)->getNodeValue) {
        if (blessed($cv) and $cv->isa('XML::API::Element')) {
            return 1;
        }
        return;
    }
    # if our next sibling is an element...
    elsif (ref($i->getParent) eq 'Tree::Simple' and 
           $i->getIndex < $i->getParent->getChildCount - 1) {
        my $nv = $i->getSibling($i->getIndex + 1)->getNodeValue;
        if (blessed($nv) and $nv->isa('XML::API::Element')) {
            return 1;
        }
        return;
    }
    # No sibling so next tag will be a closing...
    return 1;
}

sub _next_sib_is_element {
    my $i = shift;
    # if our next sibling is an element...
    if (ref($i->getParent) eq 'Tree::Simple' and 
           $i->getIndex < $i->getParent->getChildCount - 1) {
        my $nv = $i->getSibling($i->getIndex + 1)->getNodeValue;
        if (blessed($nv) and $nv->isa('XML::API::Element')) {
            return 1;
        }
        return;
    }
    # No sibling so next tag will be a closing...
    return 1;
}

sub _pre {
    my ($item) = @_;

    my $val = $item->getNodeValue;
    if (blessed($val) and $val->isa('XML::API::Element')) {
        if ($item->isLeaf) {
            $string .= $Indent x ($item->getDepth + 1) . $val->eopen_single;
        }
        else {
            $string .= $Indent x ($item->getDepth + 1) . $val->eopen;
        }
    }
    else {
        $string .= $val;
    }
    $string .= "\n" if (_child_next_sib_is_element($item));
}

sub _post {
    my ($item) = @_;
    return if($item->isLeaf); # _pre function already put a newline in

    my $val = $item->getNodeValue;
    if (blessed($val) and $val->isa('XML::API::Element')) {
            $string .= $Indent x (1 + $item->getDepth) . $val->eclose;
    }
    if ($item->isRoot or _next_sib_is_element($item)) {
        $string .= "\n";
    }
    return;
}

sub _as_string {
    my $self  = shift;
    return '' unless $self->{trees};
    return $self->{string} if ($self->{string});

    $string = '';

    if (ref($self) eq __PACKAGE__ or $self->{has_root_element}) {
        $string = qq{<?xml version="1.0" encoding="$self->{encoding}" ?>\n};
        $string .= $self->_doctype . "\n" if($self->_doctype);
        if ($self->{langroot}) {
            $self->{trees}->[0]->getNodeValue->{attrs}->{'xml:lang'} = $self->{langroot};
        }
    }
    foreach my $tree (@{$self->{trees}}) {
        _pre($tree);
        $tree->traverse(\&_pre,\&_post);
        _post($tree);
    }
    $string .= '<!-- ' . __PACKAGE__ . " v$VERSION -->\n"
        if ($self->{has_root_element});

    $self->{string} = $string;
    return $string;
}


=head2 $x->_fast_string( )

Returns the rendered version of the XML document without newlines or
indentation.

=cut

sub _pre_fast {
    my ($item) = @_;
    my $val = $item->getNodeValue;
    if (blessed($val) and $val->isa('XML::API::Element')) {
        return if ($val->isa('XML::API::Element::Comment'));
        $string .= $val->eopen;
    }
    else {
        $string .= $val;
    }
}

sub _post_fast {
    my ($item) = @_;
    my $val = $item->getNodeValue;
    if (blessed($val) and $val->isa('XML::API::Element')) {
        return if ($val->isa('XML::API::Element::Comment'));
        $string .= $val->eclose;
    }
}

sub _fast_string {
    my $self = shift;
    return '' unless $self->{trees};

    $string = '';

    if ($self->{has_root_element}) {
        $string = qq{<?xml version="1.0" encoding="$self->{encoding}" ?>};
        $string .= $self->_doctype if($self->_doctype);
        if ($self->{langroot}) {
            $self->{trees}->[0]->getNodeValue->{attrs}->{'xml:lang'} = $self->{langroot};
        }
    }
    foreach my $tree (@{$self->{trees}}) {
        _pre_fast($tree);
        $tree->traverse(\&_pre_fast,\&_post_fast);
        _post_fast($tree);
    }
    return $string;
}


=head2 $x->_print( )

A shortcut for "print $x->_as_string()". The "" operator is also
overloaded so it is in fact possible to simply 'print $x' as well.

=cut

sub _print {
    my $self = shift;
    print $self->_as_string(), "\n";
}


sub _escapeXML {
    my $data = $_[0];
    return unless(defined($data));
    if ($data =~ /[\&\<\>\"]/) {
        $data =~ s/\&(?!\w+\;)/\&amp\;/g;
        $data =~ s/\</\&lt\;/g;
        $data =~ s/\>/\&gt\;/g;
        $data =~ s/\"/\&quot\;/g;
    }
    return $data;
}


#
# We must specify the DESTROY function explicitly otherwise our AUTOLOAD
# function gets called at object death.
#
DESTROY {};

1;


=head1 OVERLOADING

See the source code of XML::API::XHTML for how to create a new doctype.

These are methods which may return interesting values if the
XML::API::<class> module has overloaded them.

=head2 _doctype

Returns the XML DOCTYPE declaration

=head2 _root_element

Returns the root element

=head2 _root_attrs

Returns a hashref containing default key/value attributes for the root element

=head2 _content_type

Returns a string suitable for including in a HTTP 'Content-Type' header.


=head1 COMPATABILITY

Since version 0.10 a call to new() does not automatically add the root
element to the object. If it did so you wouldn't be able to add one
object to another.

Version 0.13 made the doctype parameter to new() optional, so that
generic (ie no DOCTYPE declaration) XML documents can be created.

=head1 SEE ALSO

You can see XML::API in action in L<NCGI>.

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

A small request: if you use this module I would appreciate hearing about it.

=head1 COPYRIGHT

Copyright (C) 2004-2007 Mark Lawrence <nomad@null.net>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut

# vim: set tabstop=4 expandtab: