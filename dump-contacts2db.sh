#!/bin/bash

# Copyright (C) 2012-2013, Stachre
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>,
# or write to the Free Software Foundation, Inc., 51 Franklin Street, 
# Fifth Floor, Boston, MA  02110-1301, USA.
#
#
# dump-contacts2db.sh
# Version 0.4, 2013-02-11
# Dumps contacts from an Android contacts2.db to stdout in vCard format
# Usage:  dump-contacts2db.sh path/to/contacts2.db > path/to/output-file.vcf
# Dependencies:  perl; base64; sqlite3 / libsqlite3-dev

# expects single argument, path to contacts2.db
if [ "$#" -ne 1 ]
    then echo -e "Dumps contacts from an Android contacts2.db to stdout in vCard format\n"
    echo -e "Usage:  dump-contacts2db.sh path/to/contacts2.db > path/to/output-file.vcf\n"
    echo -e "Dependencies:  perl; base64; sqlite3 / libsqlite3-dev"
    exit 1
fi

# TODO: verify specified contacts2.db file exists

# inits
declare -i cur_contact_id=0
declare -i prev_contact_id=0

CONTACTS2_PATH=$1

# store Internal Field Separator
ORIG_IFS=$IFS

function replace_newlines()
{
	local FIELD="$1"
	echo "REPLACE(REPLACE(REPLACE(${FIELD},X'0D0A','\n'),X'0D','\n'),X'0A','\n')"
}

# fetch contact data
# TODO: order by account, with delimiters if possible
record_set=$(sqlite3 $CONTACTS2_PATH "SELECT raw_contacts._id, raw_contacts.display_name, raw_contacts.display_name_alt, mimetypes.mimetype, $(replace_newlines data.data1 ), data.data2, $(replace_newlines data.data4), data.data5, data.data6, data.data7, data.data8, data.data9, data.data10, quote(data.data15) FROM raw_contacts, data, mimetypes WHERE raw_contacts.deleted = 0 AND raw_contacts._id = data.raw_contact_id AND data.mimetype_id = mimetypes._id ORDER BY raw_contacts._id, mimetypes._id, data.data2")

# modify Internal Field Separator for parsing rows from recordset
IFS=`echo -e "\n\r"`

# iterate through contacts data rows
# use "for" instead of piped "while" to preserve var values post-loop
for row in $record_set
do
    # modify Internal Field Separator for parsing cols from row
    IFS="|"

    i=0

    for col in $row
    do
        i=$[i+1]

        # contact data fields stored in generic value columns
        # schema determined by "mimetype", which varies by row
        case $i in
            1)    # raw_contacts._id
                cur_contact_id=$col
                ;;

            2)    # raw_contacts.display_name
                cur_display_name=$col
                ;;

            3)    # raw_contacts.display_name_alt
                # replace comma-space with semicolon
                cur_display_name_alt=${col/, /\;}
                ;;

            4)    # mimetypes.mimetype
                cur_mimetype=$col
                ;;

            5)    # data.data1
                cur_data1=$col
                ;;

            6)    # data.data2
                cur_data2=$col
                ;;

            7)    # data.data4
                cur_data4=$col
                ;;

            8)    # data.data5
                cur_data5=$col
                ;;

            9)    # data.data6
                cur_data6=$col
                ;;

            10)    # data.data7
                cur_data7=$col
                ;;

            11)    # data.data8
                cur_data8=$col
                ;;

            12)    # data.data9
                cur_data9=$col
                ;;

            13)    # data.data10
                cur_data10=$col
                ;;

            14)    # data.data15
                cur_data15=$col
                ;;

        esac
    done

    # new contact
    if [ $prev_contact_id -ne $cur_contact_id ]; then
        if [ $prev_contact_id -ne 0 ]; then
            # echo current vcard prior to reinitializing variables
            
            # some contacts apps don't have IM fields; add to top of NOTE: field
            if [ ${#cur_vcard_im_note} -ne 0 ]
                then cur_vcard_note=$cur_vcard_im_note"\n"$cur_vcard_note
            fi

            # generate and echo vcard
            if [ ${#cur_vcard_note} -ne 0 ]
                then cur_vcard_note="NOTE:"$cur_vcard_note$'\n'
            fi
            cur_vcard=$cur_vcard$cur_vcard_nick$cur_vcard_org$cur_vcard_title$cur_vcard_tel$cur_vcard_adr$cur_vcard_email$cur_vcard_url$cur_vcard_note$cur_vcard_photo$cur_vcard_im
            cur_vcard=$cur_vcard"END:VCARD"
            echo $cur_vcard
        fi

        # init new vcard
        cur_vcard="BEGIN:VCARD"$'\n'"VERSION:3.0"$'\n'
        cur_vcard=$cur_vcard"N:"$cur_display_name_alt$'\n'"FN:"$cur_display_name$'\n'
        cur_vcard_nick=""
        cur_vcard_org=""
        cur_vcard_title=""
        cur_vcard_tel=""
        cur_vcard_adr=""
        cur_vcard_email=""
        cur_vcard_url=""
        cur_vcard_im=""
        cur_vcard_im_note=""
        cur_vcard_note=""
        cur_vcard_photo=""
    fi

    # add current row to current vcard
    # again, "mimetype" determines schema on a row-by-row basis
    # TODO: handle following types
    #   * (6) vnd.android.cursor.item/sip_address
    #   * (7) vnd.android.cursor.item/identity (not exported by Android 4.1 Jelly Bean) 
    #   * (13) vnd.android.cursor.item/group_membership (not exported by Android 4.1 Jelly Bean) 
    #   * (14) vnd.com.google.cursor.item/contact_misc (not exported by Android 4.1 Jelly Bean) 
    case $cur_mimetype in
        vnd.android.cursor.item/nickname)
            if [ ${#cur_data1} -ne 0 ]
                then cur_vcard_nick="NICKNAME:"$cur_data1$'\n'
            fi
            ;;

        vnd.android.cursor.item/organization)
            if [ ${#cur_data1} -ne 0 ]
                then cur_vcard_org=$cur_vcard_org"ORG:"$cur_data1$'\n'
            fi
            
            if [ ${#cur_data4} -ne 0 ]
                then cur_vcard_title="TITLE:"$cur_data4$'\n'
            fi
            ;;

        vnd.android.cursor.item/phone_v2)
            case $cur_data2 in
                1)
                    cur_vcard_tel_type="HOME,VOICE"
                    ;;

                2)
                    cur_vcard_tel_type="CELL,VOICE,PREF"
                    ;;

                3)
                    cur_vcard_tel_type="WORK,VOICE"
                    ;;

                4)
                    cur_vcard_tel_type="WORK,FAX"
                    ;;

                5)
                    cur_vcard_tel_type="HOME,FAX"
                    ;;

                6)
                    cur_vcard_tel_type="PAGER"
                    ;;

                7)
                    cur_vcard_tel_type="OTHER"
                    ;;

                8)
                    cur_vcard_tel_type="CUSTOM"
                    ;;

                9)
                    cur_vcard_tel_type="CAR,VOICE"
                    ;;
            esac

            cur_vcard_tel=$cur_vcard_tel"TEL;TYPE="$cur_vcard_tel_type":"$cur_data1$'\n'
            ;;

        vnd.android.cursor.item/postal-address_v2)
            case $cur_data2 in
                1)
                    cur_vcard_adr_type="HOME"
                    ;;

                2)
                    cur_vcard_adr_type="WORK"
                    ;;
            esac

            # ignore addresses that contain only USA (MS Exchange)
            # TODO: validate general address pattern instead
            if [ $cur_data1 != "United States of America" ]
                then cur_vcard_adr=$cur_vcard_adr"ADR;TYPE="$cur_vcard_adr_type":;;"$cur_data4";"$cur_data7";"$cur_data8";"$cur_data9";"$cur_data10$'\n'
                cur_vcard_adr=$cur_vcard_adr"LABEL;TYPE="$cur_vcard_adr_type":"$cur_data1$'\n'
            fi
            ;;

        vnd.android.cursor.item/email_v2)
            cur_vcard_email=$cur_vcard_email"EMAIL:"$cur_data1$'\n'
            ;;

        vnd.android.cursor.item/website)
            cur_vcard_url=$cur_vcard_url"URL:"$cur_data1$'\n'
            ;;

        vnd.android.cursor.item/im)
             # handle entire string within each case to avoid unhandled cases
             case $cur_data5 in
                -1)
                    cur_vcard_im_note=$cur_vcard_im_note"IM-Custom-"$cur_data6": "$cur_data1"\n"
                    ;;

                0)
                    cur_vcard_im=$cur_vcard_im"X-AIM:"$cur_data1$'\n'
                    cur_vcard_im_note=$cur_vcard_im_note"IM-AIM: "$cur_data1"\n"
                    ;;

                1)
                    cur_vcard_im=$cur_vcard_im"X-MSN:"$cur_data1$'\n'
                    cur_vcard_im_note=$cur_vcard_im_note"IM-MSN: "$cur_data1"\n"
                    ;;

                2)
                    cur_vcard_im=$cur_vcard_im"X-YAHOO:"$cur_data1$'\n'
                    cur_vcard_im_note=$cur_vcard_im_note"IM-Yahoo: "$cur_data1"\n"
                    ;;

                3)
                    cur_vcard_im=$cur_vcard_im"X-SKYPE-USERNAME:"$cur_data1$'\n'
                    cur_vcard_im_note=$cur_vcard_im_note"IM-Skype: "$cur_data1"\n"
                    ;;

                4)
                    cur_vcard_im=$cur_vcard_im"X-QQ:"$cur_data1$'\n'
                    cur_vcard_im_note=$cur_vcard_im_note"IM-QQ: "$cur_data1"\n"
                    ;;

                5)
                    cur_vcard_im=$cur_vcard_im"X-GOOGLE-TALK:"$cur_data1$'\n'
                    cur_vcard_im_note=$cur_vcard_im_note"IM-Google-Talk: "$cur_data1"\n"
                    ;;

                6)
                    cur_vcard_im=$cur_vcard_im"X-ICQ:"$cur_data1$'\n'
                    cur_vcard_im_note=$cur_vcard_im_note"IM-ICQ: "$cur_data1"\n"
                    ;;

                7)
                    cur_vcard_im=$cur_vcard_im"X-JABBER:"$cur_data1$'\n'
                    cur_vcard_im_note=$cur_vcard_im_note"IM-Jabber: "$cur_data1"\n"
                    ;;

                *)
                    # Android 2.3 Gingerbread doesn't identify service; data5==""
                    cur_vcard_im_note=$cur_vcard_im_note"IM: "$cur_data1"\n"
                    ;;
            esac
            ;;

        vnd.android.cursor.item/photo)
            if [ $cur_data15 != "NULL" ]; then
                # Remove the prefix "X'" and suffix "'" from the sqlite3 quote(BLOB) hex output
                photo=`echo $cur_data15 | sed -e "s/^X'//" -e "s/'$//"`
                
                # Convert the hex to base64
                # TODO: optimize
                photo=`echo $photo | perl -ne 's/([0-9a-f]{2})/print chr hex $1/gie' | base64 --wrap=0`
                
                cur_vcard_photo=$cur_vcard_photo"PHOTO;ENCODING=BASE64;JPEG:"$photo$'\n'
                
                # TODO: line wrapping; Android import doesn't like base64's wrapping
                
                # For testing
                #echo $cur_data15 > "images/$cur_display_name.txt"
                #echo $cur_data15 | perl -ne 's/([0-9a-f]{2})/print chr hex $1/gie' > "images/$cur_display_name.jpg"
            fi
            ;;

        vnd.android.cursor.item/note)
            # "NOTE:" and trailing \n appended when vCard is finished and echoed
            if [ ${#cur_vcard_note} -ne 0 ]
                then cur_vcard_note=$cur_vcard_note"\n\n"$cur_data1
                else cur_vcard_note=$cur_data1
            fi
            ;;
    esac    

    prev_contact_id=$cur_contact_id

    # reset Internal Field Separator for parent loop
    IFS=`echo -e "\n\r"`
done

# set Internal Field Separator to other-than-newline prior to echoing final vcard
IFS="|"

# some contacts apps don't have IM fields; add to top of NOTE: field
if [ ${#cur_vcard_im_note} -ne 0 ]
    then cur_vcard_note=$cur_vcard_im_note"\n"$cur_vcard_note
fi

# generate and echo vcard
if [ ${#cur_vcard_note} -ne 0 ]
    then cur_vcard_note="NOTE:"$cur_vcard_note$'\n'
fi
cur_vcard=$cur_vcard$cur_vcard_nick$cur_vcard_org$cur_vcard_title$cur_vcard_tel$cur_vcard_adr$cur_vcard_email$cur_vcard_url$cur_vcard_note$cur_vcard_photo$cur_vcard_im
cur_vcard=$cur_vcard"END:VCARD"
echo $cur_vcard

# restore original Internal Field Separator
IFS=$ORIG_IFS

