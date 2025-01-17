#!/usr/local/bin/bash
set -eu

files=("base" "ext" "sogou" "tencent" "emoji")
iceRepoPath="${HOME}/gitrepos/rime-ice"
repoRoot="$(git rev-parse --show-toplevel)"
scriptPath=$(dirname "$(realpath "$0")")
pyScrPath="${scriptPath}/flypy_dict_generator_new.py"
rimeUserPath="${HOME}/Library/Rime"
rimeDeployer="/Library/Input Methods/Squirrel.app/Contents/MacOS/rime_deployer"
prevCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
# prevCommit="51461d7"
git -C "${iceRepoPath}" pull

curCommit=$(git -C "${iceRepoPath}" rev-parse --short HEAD)
# curCommit="272c706"
[[ ${curCommit} == "${prevCommit}" ]] && exit

gcp -aR "${iceRepoPath}"/en_dicts/*.dict.yaml "${repoRoot}/en_dicts/"
gsed -i -r '/^(Oz|Oq|Oe|Od)/d' "${repoRoot}/en_dicts/en.dict.yaml"

for f in "${files[@]}";
do
    echo -e "\n----------\n" "$f"  "\n----------\n"
    src_file="${iceRepoPath}/cn_dicts/$f.dict.yaml"
    tgt_file="${repoRoot}/cn_dicts/flypy_${f}.dict.yaml"
    [[ "$f" == "emoji" ]] && src_file="${iceRepoPath}/opencc/emoji.txt"
    [[ "$f" == "emoji" ]] && tgt_file="${repoRoot}/opencc/emoji.txt"

    if [[ "$f" == "base" ]] || [[ "$f" == "emoji" ]]; then
        git -C "${iceRepoPath}" diff ${prevCommit}..HEAD -- "${src_file}" |\
            /usr/local/bin/rg  "^\-" |\rg -v "\-#|\+v|\---" |tr -d "-" > "${f}_min.diff"
        gcut -f1 "${f}_min.diff" |gxargs -I % -n 1 gsed -i '/^%$/d' "${tgt_file}"
    fi
    git -C "${iceRepoPath}" diff ${prevCommit}..HEAD -- "${src_file}" |\
        /usr/local/bin/rg "^\+" |\rg -v "\+#|\+v|\+\+" |tr -d "+" > "${f}_add.diff"

    [[ "$f" == "emoji" ]] && awk '{print $1"\t"$2,$3}' "${f}_add.diff" >> "${tgt_file}"
    if [[ $(cat "${f}_add.diff" |wc -l |tr -d ' ') != 0 ]] && [[ $f != "emoji" ]]; then
        if [[ "$f" == "base" ]] || [[ "$f" == "sogou" ]]; then
            python3.11 "${pyScrPath}" -i "${f}_add.diff" -o "${tgt_file}" -m
        else
            python3.11 "${pyScrPath}" -i "${f}_add.diff" -o "${tgt_file}" -m -c
        fi
    fi

    [[ "${f}" == "base" ]] && {
        rg '^..\t.*'  "${f}_add.diff" > "${f}_twords.txt"
        python3.11 "${pyScrPath}" -i "${f}_twords.txt" -x -o "${repoRoot}/flypy_twords.txt"
        twords_file="${repoRoot}/flypy_phrase_fzm.dict.yaml"
        awk -F'[ \t[]+' '{x=substr($3,1,1);y=substr($5,1,1);print $1"\t",$2$4y x"\t",$NF}' flypy_twords.txt >> "${twords_file}"
        gcut -f1 "${f}_min.diff" |gxargs -I % -n 1 gsed -i '/^%$/d' "${twords_file}"
        rm "${f}_twords.txt" "${repoRoot}/flypy_twords.txt"
    }

    rm "${f}_add.diff" && [[ $f =~ base|emoji ]] && rm "${f}_min.diff"
done

gcp -ar ${repoRoot}/cn_dicts/* "${rimeUserPath}/cn_dicts/"
gcp -ar ${repoRoot}/en_dicts/* "${rimeUserPath}/en_dicts/"
gcp -ar ${repoRoot}/opencc/* "${rimeUserPath}/opencc/"
gcp -ar flypy_phrase_fzm.dict.yaml ~/Library/Rime/
cd "${rimeUserPath}" && "${rimeDeployer}" --compile "${rimeUserPath}/flypy_xhfast.schema.yaml" > /dev/null && echo 'enjoy rime'
