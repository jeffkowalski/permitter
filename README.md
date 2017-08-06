Permitter for BART Select-a-Spot
===

Permitter reserves permits at BART using Select-a-Spot.  It requires an active account on Select-a-Spot.

## Installation

Note: Ruby is required

``` sh
# Download the repository.
git clone git://github.com/jeffkowalski/permitter.git

# Get the ruby gem dependencies.
cd permitter
bundle install

```

## Configuration

Create a file named ```credentials.yml``` containing your login to Select-a-Spot.  Because the contents are in clear-text, it is wise to change permissions on this file to be readable by user only (i.e. 0600 on Unix).

``` yaml
---
:username: 'foo.bar@example.com'
:password: 'secret'
```

Create a file named ```date.yml``` with the first date to reserve.  The permitter will automatically re-write this file with the advancing date of the next reservation.

``` yaml
--- 2017-10-06
...
```

## Usage

``` shell
# For interactive usage,
ruby ./permitter.rb get --no-log

# Or, for use in scripts or cron jobs,
ruby ./permitter.rb get
```
