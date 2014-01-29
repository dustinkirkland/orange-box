#!/usr/bin/python

import sys
import psycopg2
import argparse


def get_user_oauth(user='admin'):
    con = None
    try:
        con = psycopg2.connect(database='maasdb', user='postgres')
        cur = con.cursor()
        cur.execute("SELECT c.key as consumer_key, t.key, t.secret FROM "
                    "piston_token as t inner join piston_consumer as c on "
                    "t.consumer_id = c.id inner join auth_user as u on "
                    "t.user_id = u.id WHERE u.username = '%s'" % user)
        ver = cur.fetchone()
    except psycopg2.DatabaseError:
        raise
    finally:
        if con:
            con.close()
    if not ver:
        raise Exception('No key found')

    return "%s:%s:%s" % ver


def main():
    parser = argparse.ArgumentParser(description='Do something naughty, pull '
                                     'from db.')
    parser.add_argument('user', nargs=1, default='admin', help='MAAS user')

    a = parser.parse_args()

    try:
        key = get_user_oauth(a.user)
    except Exception as e:
        print 'Error %s' % e
        sys.exit(1)

    print key

if __name__ == '__main__':
    main()
