#!/bin/bash

AGENT='User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:68.0) Gecko/20100101 Firefox/68.0'
# [TODO] COOKIE: --load-cookies cookie
# sqlite3 ./firefox/*/cookies.sqlite
# sqlite> select * from moz_cookies where baseDomain like 'ok.ru';

getImg() {

	PROFILE_LINK="$1"
	ALBUM_ID="$2"
	THUMB_ID="$3"

	if [ -z "${PROFILE_LINK}" -o -z "${ALBUM_ID}" -o -z "${THUMB_ID}" ]; then

		echo "[-] profile_link:${PROFILE_LINK} album_id:${ALBUM_ID} thumbi_id:${THUMB_ID}"
		return

	fi

	if [ -f "${ALBUM_ID}/${THUMB_ID}.jpg" ]; then

		echo "[.] ${ALBUM_ID}/${THUMB_ID}.jpg (exists}"

	else

		DATA=$(wget -U "${AGENT}" -qO - "${PROFILE_LINK}/${ALBUM_ID}/${THUMB_ID}")

		if [[ "$DATA" =~ (data-nfs-src=\"//i\.mycdn\.me/i\?r=([^\"]+)\") ]]; then
			IMG_ID="${BASH_REMATCH[2]}"
			IMG_LINK="https://i.mycdn.me/i?r=${IMG_ID}"
			wget -qO "${ALBUM_ID}/${THUMB_ID}.jpg" "${IMG_LINK}"
			echo "[$?] ${ALBUM_ID}/${THUMB_ID}.jpg"
		fi

	fi

}

if [ -n "$1" ]; then

	PROFILE_LINK=$(dirname "$1")
	ALBUM_ID=$(basename "$1")

	if [ -n "${PROFILE_LINK}" -a -n "${ALBUM_ID}" ]; then

		echo "[i] profile_link:${PROFILE_LINK} album_id:${ALBUM_ID}"
		mkdir -p "${ALBUM_ID}"
		DATA=$(wget -U "${AGENT}" -qO - "${PROFILE_LINK}/${ALBUM_ID}")
		for N in $(echo "$DATA" | grep -Eo 'id="img_[^"]+"'); do
			if [[ "$N" =~ (id=\"img_([^\"]+)\") ]]; then
				THUMB_ID="${BASH_REMATCH[2]}"
				getImg "${PROFILE_LINK}" "${ALBUM_ID}" "${THUMB_ID}"
			fi
		done

		PAGE=1
		[[ "$DATA" =~ (gwt\.requested=([^\"]+)\") ]] && GWT_REQUESTED="${BASH_REMATCH[2]}"
		[[ "$DATA" =~ (st\.friendId=([^\&]+)\&) ]] && ST_FRIENDID="${BASH_REMATCH[2]}"
		[[ "$DATA" =~ (data-last-element=\"([^\"]+)\") ]] && ST_LASTELEM="${BASH_REMATCH[2]}"
		while [ -n "${GWT_REQUESTED}" -a -n "${ST_FRIENDID}" -a -n "${ST_LASTELEM}" ]; do
			(( PAGE+=1 ))
			POST_DATA="fetch=false&st.page=${PAGE}&st.albumId=${ALBUM_ID}&st.friendId=${ST_FRIENDID}&st.lastelem=${ST_LASTELEM}&gwt.requested=${GWT_REQUESTED}"
			DATA=$(wget -U "${AGENT}" -qO - --post-data "${POST_DATA}" "${PROFILE_LINK}/${ALBUM_ID}?cmd=UserAlbumPhotosMRB")
			echo "[i] page:${PAGE}"
			echo "$DATA" > page$PAGE.txt
			for N in $(echo "$DATA" | grep -Eo 'id="img_[^"]+"'); do
				if [[ "$N" =~ (id=\"img_([^\"]+)\") ]]; then
					THUMB_ID="${BASH_REMATCH[2]}"
					getImg "${PROFILE_LINK}" "${ALBUM_ID}" "${THUMB_ID}"
				fi
			done
			[[ "$DATA" =~ (st\.lastelem=([^\&]+)\&) ]] && ST_LASTELEM="${BASH_REMATCH[2]}" || ST_LASTELEM=''
		done

	else

		echo "[-] profile_link:${PROFILE_LINK} album_id:${ALBUM_ID}"

	fi

else

	echo "usage $0 link_to_any_photo_in_albums"

fi

