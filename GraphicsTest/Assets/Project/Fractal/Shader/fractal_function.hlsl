half2 cadd(half2 a, half s)
{
    return half2(a.x + s, a.y);
}

half2 cmul(half2 a, half2 b)
{
    return half2( a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x );
}

half2 cdiv(half2 a, half2 b)
{
    float d = dot(b,b); 
    return half2( dot(a, b), a.y * b.x - a.x * b.y ) / d;
}

half2 csqr(half2 a)
{
    return half2(a.x * a.x - a.y * a.y, 2.0 * a.x * a.y );
}

half2 csqrt(half2 z)
{
    half m = length(z); 
    return sqrt( 0.5 * half2(m + z.x, m - z.x) ) * half2( 1.0, sign(z.y) );
}

half2 conj(half2 z)
{
    return half2(z.x, -z.y);
}

half2 cpow(half2 z, half n)
{
    half r = length( z ); 
    half a = atan( z.y / z.x ); 
    return pow( r, n ) * half2( cos(a * n), sin(a * n) );
}

half2 f( half2 z, half2 c)
{
	return c + cdiv(cmul((z - half2(0.0, 1.0)), cmul( cpow(z - half2(1,1), 4.0), (z - half2(-0.1,-0.1)))), cmul( z - half2(1.0, 1.0), z + 1.0));
}

half2 df(half2 z, half2 c)
{
	half2 e = half2(0.001, 0.0);
    return cdiv( f(z, c) - f(z + e, c), e );
}