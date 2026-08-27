import gzip
import html
import os
from functools import lru_cache

import ftfy
import numpy as np
import regex as re


@lru_cache()
def bytes_to_unicode():
    bs = list(range(ord("!"), ord("~") + 1))
    bs += list(range(ord("¡"), ord("¬") + 1))
    bs += list(range(ord("®"), ord("ÿ") + 1))

    cs = bs[:]
    n = 0

    for b in range(256):
        if b not in bs:
            bs.append(b)
            cs.append(256 + n)
            n += 1

    cs = [chr(n) for n in cs]
    return dict(zip(bs, cs))


def get_pairs(word):
    pairs = set()
    prev = word[0]

    for char in word[1:]:
        pairs.add((prev, char))
        prev = char

    return pairs


def basic_clean(text):
    text = ftfy.fix_text(text)
    text = html.unescape(html.unescape(text))
    return text.strip()


def whitespace_clean(text):
    text = re.sub(r"\s+", " ", text)
    return text.strip()


class SimpleTokenizer:
    def __init__(self):
        base_dir = os.path.dirname(os.path.abspath(__file__))

        bpe_path = os.path.join(
            base_dir,
            "bpe_simple_vocab_16e6.txt.gz"
        )

        self.byte_encoder = bytes_to_unicode()
        self.byte_decoder = {
            v: k for k, v in self.byte_encoder.items()
        }

        merges = gzip.open(bpe_path).read().decode("utf-8").split("\n")
        merges = merges[1:49152 - 256 - 2 + 1]
        merges = [tuple(merge.split()) for merge in merges]

        vocab = list(self.byte_encoder.values())
        vocab += [v + "</w>" for v in vocab]

        for merge in merges:
            vocab.append("".join(merge))

        vocab.extend([
            "<|startoftext|>",
            "<|endoftext|>",
        ])

        self.encoder = {
            token: index
            for index, token in enumerate(vocab)
        }

        self.bpe_ranks = dict(zip(merges, range(len(merges))))
        self.cache = {
            "<|startoftext|>": "<|startoftext|>",
            "<|endoftext|>": "<|endoftext|>",
        }

        self.pattern = re.compile(
            r"""<\|startoftext\|>|<\|endoftext\|>|'s|'t|'re|'ve|'m|'ll|'d|[^\s\p{L}\p{N}]+|[\p{L}]+|[\p{N}]""",
            re.IGNORECASE,
        )

        self.sot_token = self.encoder["<|startoftext|>"]
        self.eot_token = self.encoder["<|endoftext|>"]

    def bpe(self, token):
        if token in self.cache:
            return self.cache[token]

        word = tuple(token[:-1]) + (token[-1] + "</w>",)
        pairs = get_pairs(word)

        if not pairs:
            return token + "</w>"

        while True:
            bigram = min(
                pairs,
                key=lambda pair: self.bpe_ranks.get(
                    pair,
                    float("inf")
                ),
            )

            if bigram not in self.bpe_ranks:
                break

            first, second = bigram
            new_word = []
            i = 0

            while i < len(word):
                try:
                    j = word.index(first, i)
                    new_word.extend(word[i:j])
                    i = j
                except ValueError:
                    new_word.extend(word[i:])
                    break

                if (
                    word[i] == first
                    and i < len(word) - 1
                    and word[i + 1] == second
                ):
                    new_word.append(first + second)
                    i += 2
                else:
                    new_word.append(word[i])
                    i += 1

            word = tuple(new_word)

            if len(word) == 1:
                break

            pairs = get_pairs(word)

        result = " ".join(word)
        self.cache[token] = result

        return result

    def encode(self, text):
        bpe_tokens = []

        text = whitespace_clean(
            basic_clean(text)
        ).lower()

        for token in re.findall(self.pattern, text):
            token = "".join(
                self.byte_encoder[b]
                for b in token.encode("utf-8")
            )

            bpe_tokens.extend(
                self.encoder[bpe_token]
                for bpe_token in self.bpe(token).split(" ")
            )

        return bpe_tokens

    def tokenize(self, text, context_length=77):
        tokens = [
            self.sot_token,
            *self.encode(text),
            self.eot_token,
        ]

        if len(tokens) > context_length:
            tokens = tokens[:context_length]
            tokens[-1] = self.eot_token

        result = np.zeros(
            (1, context_length),
            dtype=np.int64,
        )

        result[0, :len(tokens)] = tokens

        eot_index = np.array(
            [len(tokens) - 1],
            dtype=np.int64,
        )

        return result, eot_index