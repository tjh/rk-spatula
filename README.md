# Description

Library for scraping RunKeeper.com data for (please use responsibly)

# Examples

Get the total miles for all activities in March, 2012 for user
'timharvey':

    Runkeeper.monthly_miles('timharvey', 2012, 3) # => 141.56

Get information about a specific activity:

    activity = Runkeeper::Activity.new('/user/timharvey/activity/68786033')
    activity.miles           # => 9.89
    activity.started_at.to_s # => '2012-01-30T17:21:55+00:00'
    activity.number          # => '68786033'

# License

This code is [Uncopyrighted](http://mnmlist.com/uncopyright-and-a-minimalist-mindset/). Its author, Tim Harvey, has 
released all claims on copyright and has put all the content of this code into the public domain.

No permission is needed to copy, distribute, or modify the content of this code repository. Credit is appreciated 
but not required.
