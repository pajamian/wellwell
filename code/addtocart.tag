UserTag addtocart Order sku quantity
UserTag addtocart AddAttr
UserTag addtocart Routine <<EOR
sub {
	my ($sku, $quantity, $opt) = @_;
    my ($product_ref, %item);

	$quantity ||= 1;
	
    %item = (code => $sku,
			 quantity => $quantity,
			 mv_mi => 1,
			 mv_si => 0);

	$Tag->perl({tables => 'products'});
	
	$product_ref = $Db{products}->row_hash($sku);
	
	for (@{$Config->{AutoModifier}}) {
		$item{$_} = $opt->{$_} || $product_ref->{$_};
	}

    push(@$Items, \%item);

    return;
}
EOR
