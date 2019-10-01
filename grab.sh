#!/bin/bash

AGENT='Mozilla/5.0 (X11; Linux x86_64; rv:68.0) Gecko/20100101 Firefox/68.0'

WGET() {
	wget --referer="https://${SITE}/" -U "${AGENT}" --header="Cookie: ${COOKIE}" -q $@
}

pageParser() {
	for N in $(echo "$DATA" | grep -Eo 'id="img_[^"]+"'); do
		if [[ "$N" =~ (id=\"img_([^\"]+)\") ]]; then
			THUMB_ID="${BASH_REMATCH[2]}"
			getImg "${PROFILE_LINK}" "${ALBUM_ID}" "${THUMB_ID}"
		fi
	done
}

getImg() {

	PROFILE_LINK="$1"
	ALBUM_ID="$2"
	THUMB_ID="$3"

	if [ -z "${PROFILE_LINK}" -o -z "${ALBUM_ID}" -o -z "${THUMB_ID}" ]; then
		echo "[-] profile_link:${PROFILE_LINK} album_id:${ALBUM_ID} thumbi_id:${THUMB_ID}"
		return
	fi

	if [ -f "${ALBUM_ID}/${THUMB_ID}.jpg" ]; then
		echo "[.] ${ALBUM_ID}/${THUMB_ID}.jpg ($CNT:exists}"
	else
		(( CNT+=1 ))
		DATA=$(WGET -O - "${PROFILE_LINK}/${ALBUM_ID}/${THUMB_ID}")
		if [[ "$DATA" =~ (data-nfs-src=\"//i\.mycdn\.me/i\?r=([^\"]+)\") ]]; then
			IMG_ID="${BASH_REMATCH[2]}"
			IMG_LINK="https://i.mycdn.me/i?r=${IMG_ID}"
			WGET -O "${ALBUM_ID}/${THUMB_ID}.jpg" "${IMG_LINK}"
			echo "[$?] ${ALBUM_ID}/${THUMB_ID}.jpg ($CNT)"
		fi
	fi

}

if [ -n "$1" ]; then

	CNT=0
	PROFILE_LINK=$(dirname "$1")
	ALBUM_ID=$(basename "$1")
	SITE="${PROFILE_LINK/*\/\//}"; SITE="${SITE/\/*/}"
	COOKIE=$(sqlite3 -list `find ~/.mozilla/firefox -name cookies.sqlite` "SELECT name||'='||value||';' FROM moz_cookies WHERE baseDomain='ok.ru'"); COOKIE="${COOKIE//$'\n'}"

	if [ -n "${PROFILE_LINK}" -a -n "${ALBUM_ID}" -a -n "${COOKIE}" ]; then
		echo "[i] profile_link:${PROFILE_LINK} album_id:${ALBUM_ID}"
		mkdir -p "${ALBUM_ID}"
		DATA=$(WGET --server-response -O - "${PROFILE_LINK}/${ALBUM_ID}" 2>&1)
		PAGE=1
		pageParser 
		[[ "$DATA" =~ (Set-Cookie: JSESSIONID=([^;]+);) ]] && COOKIE="JSESSIONID=${BASH_REMATCH[2]}; ${COOKIE}"
		[[ "$DATA" =~ (data-last-element=\"([^\"]+)\") ]] && ST_LASTELEM="${BASH_REMATCH[2]}"
		[[ "$DATA" =~ (gwt\.requested=([^\"]+)\") ]] && GWT_REQUESTED="${BASH_REMATCH[2]}"
		[[ "$DATA" =~ (gwtHash:\"([^\"]+)\") ]] && GWT_REQUESTED="${BASH_REMATCH[2]}"
		[[ "$DATA" =~ (st\.friendId=([^\&]+)\&) ]] && ST_FRIENDID="${BASH_REMATCH[2]}"
		[[ "$DATA" =~ (OK\.tkn\.set\(\'([^\']+)\'\)\;) ]] && TKN="${BASH_REMATCH[2]}"
		while [ -n "${GWT_REQUESTED}" -a -n "${ST_LASTELEM}" ]; do
			(( PAGE+=1 ))
			echo "[i] PAGE:${PAGE}"
			POST_DATA="st.albumId=${ALBUM_ID}&st.friendId=${ST_FRIENDID}&fetch=false&st.lastelem=${ST_LASTELEM}"
			DATA=$(WGET -O - --header "TKN:${TKN}" --post-data "${POST_DATA}" "${PROFILE_LINK}/${ALBUM_ID}?cmd=UserAlbumPhotosMRB&gwt.requested=${GWT_REQUESTED}&st.cmd=friendAlbumPhotos&st.friendId=${ST_FRIENDID}&st.albumIds=${ALBUM_ID}&")
			pageParser
			if [[ "$DATA" =~ (st\.lastelem=([^\&]+)\&) ]]; then
				ST_LASTELEM="${BASH_REMATCH[2]}"
			elif [[ "$DATA" =~ (data-last-element=\"([^\"]+)\") ]]; then
				ST_LASTELEM="${BASH_REMATCH[2]}"
			else
				ST_LASTELEM=''
			fi
		done
	else
		echo "[-] profile_link:${PROFILE_LINK} album_id:${ALBUM_ID}"
	fi

else
	echo "usage $0 link_to_any_photo_in_albums"
fi
