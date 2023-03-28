#!/usr/local/bin/python3.11

import sys
from pathlib import PosixPath as pp

# from pypinyin import lazy_pinyin

dict_head = """
# Rime dictionary
# encoding: utf-8
## Based on http://gerry.lamost.org/blog/?p=296003

---
name: base_flypy
version: "2023.3.27"
sort: by_weight
use_preset_vocabulary: true  # 導入八股文字頻
max_phrase_length: 1         # 不生成詞彙
...
"""


def pinyin_to_flypy(pinyin: list[str]):
    def to_flypy(pinyin: str):
        shengmu_dict = {"zh": "v", "ch": "i", "sh": "u"}
        yunmu_dict = {
            "ou": "z",
            "iao": "n",
            "uang": "l",
            "iang": "l",
            "en": "f",
            "eng": "g",
            "ang": "h",
            "an": "j",
            "ao": "c",
            "ai": "d",
            "ian": "m",
            "in": "b",
            "uo": "o",
            "un": "y",
            "iu": "q",
            "uan": "r",
            "iong": "s",
            "ong": "s",
            "ue": "t",
            "üe": "t",
            "ui": "v",
            "ua": "x",
            "ia": "x",
            "ie": "p",
            "uai": "k",
            "ing": "k",
            "ei": "w",
        }
        zero = {
            "a": "aa",
            "an": "an",
            "ang": "ah",
            "o": "oo",
            "ou": "ou",
            "e": "ee",
            "n": "en",
            "en": "en",
            "eng": "eg",
        }
        if pinyin in zero.keys():
            return zero[pinyin]
        else:
            if pinyin[1] == "h":
                shengmu = shengmu_dict[pinyin[:2]]
                yunmu = (
                    yunmu_dict[pinyin[2:]]
                    if pinyin[2:] in yunmu_dict.keys()
                    else pinyin[2:]
                )
                return shengmu + yunmu
            else:
                shengmu = pinyin[:1]
                yunmu = (
                    yunmu_dict[pinyin[1:]]
                    if pinyin[1:] in yunmu_dict.keys()
                    else pinyin[1:]
                )
                return shengmu + yunmu

    return [to_flypy(x) for x in pinyin]


def quanpin_to_flypy(line_content, *args):
    data_list = line_content.strip().split()
    if args[0]:
        from pypinyin import lazy_pinyin

        pinyin_list = lazy_pinyin(data_list[0], v_to_u=True)
    else:
        pinyin_list = [i for i in data_list if i.isascii() and i.isalpha()]
    if pinyin_list:
        print("pinyin_list: ", pinyin_list)
        flypy_list = pinyin_to_flypy(pinyin_list)
        word_frequency = f"\t{data_list[-1]}" if data_list[-1] else ""
        xhup_str = " ".join(flypy_list)
        item = f"{data_list[0].strip()}\t{xhup_str}{word_frequency}\n"
        yield item


def write_date_to_file(data, outfile):
    if outfile not in globals().keys():
        with open(outfile, "w") as odf:
            odf.write(dict_head)
            odf.write("\n")
    else:
        with open(outfile, "a") as odf:
            odf.write(data)

    globals().update({outfile: True})

def open_dict_and_send_line(infile):
    # lines = open(infile).readlines()  # 载入简体拆字字典
    with open(infile, "r") as df:
        for line in df.readlines():
            tl = any(
                [
                    line.startswith("#"),
                    line.startswith(" "),
                    line.startswith("-"),
                    line.startswith("."),
                    line[0].islower(),
                ]
            )
            if not tl:
                yield line
            # else:
            #     continue


def main():
    hanzi2pinyin = sys.argv[-1]
    option = None if hanzi2pinyin.endswith("yaml") else hanzi2pinyin

    pp_objs = [pp(sys.argv[i]) for i in range(1, len(sys.argv))]
    infile_names = [f for f in pp_objs if f.is_file()]
    outfile_names = [f"flypy_{f.name.split('.')[0]}.dict.yaml" for f in infile_names]
    print(infile_names, outfile_names, option)
    input_datas = [ open_dict_and_send_line(infile) for infile in infile_names ]

    for outfile, indata in zip(outfile_names, input_datas):
        for idata in indata:
            for odata in quanpin_to_flypy(idata, option):
                write_date_to_file(odata, outfile)


if __name__ == "__main__":
    main()