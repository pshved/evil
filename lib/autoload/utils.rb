
# Code by FM, licence: CC
# See here: http://stackoverflow.com/questions/1904097/how-to-calculate-how-many-years-passed-since-a-given-date-in-ruby/1904349#1904349
def age_in_completed_years (bd, d)
	# Difference in years, less one if you have not had a birthday this year.
	a = d.year - bd.year
	a = a - 1 if (
		 bd.month >  d.month or
		(bd.month >= d.month and bd.day > d.day)
	)
	a
end

# Random string generator.  Generate +n+ random characters from +alphabet+.
def generate_random_string(n, alphabet = 'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNMo1234567890')
	str = ''
	n.times { str << alphabet[rand(alphabet.size)] }
	str
end

