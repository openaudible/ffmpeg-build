/*
 * FFmpeg built-in probe mode (-probe flag)
 * Outputs JSON metadata equivalent to:
 *   ffprobe -hide_banner -show_streams -show_chapters -show_error
 *           -show_format -print_format json <input>
 *
 * This allows shipping a single ffmpeg binary without ffprobe.
 *
 * Copyright (c) 2024 OpenAudible
 * License: LGPL 2.1+ (same as FFmpeg)
 */

#include "config.h"

#include <stdio.h>
#include <string.h>
#include <inttypes.h>

#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avstring.h"
#include "libavutil/channel_layout.h"
#include "libavutil/dict.h"
#include "libavutil/opt.h"
#include "libavutil/pixdesc.h"
#include "libavutil/display.h"

/* Forward declaration (called from ffmpeg.c) */
int ffmpeg_probe_json(const char *filename);

/* JSON output helpers */

static void json_escape(FILE *f, const char *s)
{
    for (; *s; s++) {
        switch (*s) {
        case '"':  fputs("\\\"", f); break;
        case '\\': fputs("\\\\", f); break;
        case '\b': fputs("\\b", f);  break;
        case '\f': fputs("\\f", f);  break;
        case '\n': fputs("\\n", f);  break;
        case '\r': fputs("\\r", f);  break;
        case '\t': fputs("\\t", f);  break;
        default:
            if ((unsigned char)*s < 0x20)
                fprintf(f, "\\u%04x", (unsigned char)*s);
            else
                fputc(*s, f);
        }
    }
}

static void json_print_str(FILE *f, const char *key, const char *val,
                            int indent, int *first)
{
    if (!*first) fprintf(f, ",\n");
    *first = 0;
    fprintf(f, "%*s\"%s\": \"", indent, "", key);
    json_escape(f, val);
    fputc('"', f);
}

static void json_print_int(FILE *f, const char *key, long long val,
                            int indent, int *first)
{
    if (!*first) fprintf(f, ",\n");
    *first = 0;
    fprintf(f, "%*s\"%s\": %lld", indent, "", key, val);
}

/* Print a time value as a string (matches ffprobe format: "123.456000") */
static void json_print_time(FILE *f, const char *key,
                             int64_t ts, const AVRational *tb,
                             int indent, int *first)
{
    if (ts == AV_NOPTS_VALUE) {
        return;  /* Skip printing if not available */
    }
    char buf[64];
    double d = ts * av_q2d(*tb);
    snprintf(buf, sizeof(buf), "%f", d);
    json_print_str(f, key, buf, indent, first);
}

/* Print a duration time (0 means N/A) */
static void json_print_duration(FILE *f, const char *key,
                                int64_t ts, const AVRational *tb,
                                int indent, int *first)
{
    if (ts == 0) {
        return;  /* Skip printing if not available */
    }
    char buf[64];
    double d = ts * av_q2d(*tb);
    snprintf(buf, sizeof(buf), "%f", d);
    json_print_str(f, key, buf, indent, first);
}

/* Print a timestamp as an integer (matches ffprobe: integer or "N/A") */
static void json_print_ts(FILE *f, const char *key, int64_t ts,
                           int indent, int *first)
{
    if (ts == AV_NOPTS_VALUE)
        return;  /* Skip printing if not available */
    json_print_int(f, key, ts, indent, first);
}

/* Print tags object */
static void json_print_tags(FILE *f, const AVDictionary *metadata,
                             int indent)
{
    const AVDictionaryEntry *t = NULL;
    int first = 1;

    fprintf(f, ",\n%*s\"tags\": {", indent, "");
    while ((t = av_dict_get(metadata, "", t, AV_DICT_IGNORE_SUFFIX))) {
        if (!first) fprintf(f, ",");
        fprintf(f, "\n%*s\"", indent + 4, "");
        json_escape(f, t->key);
        fputs("\": \"", f);
        json_escape(f, t->value);
        fputc('"', f);
        first = 0;
    }
    if (!first) fprintf(f, "\n%*s", indent, "");
    fprintf(f, "}");
}

/* Print disposition object */
static void json_print_disposition(FILE *f, int disposition, int indent)
{
    int first = 1;

    fprintf(f, ",\n%*s\"disposition\": {\n", indent, "");

#define PRINT_DISP(flag, name) do { \
    if (!first) fprintf(f, ",\n"); \
    first = 0; \
    fprintf(f, "%*s\"%s\": %d", indent + 4, "", name, \
            !!(disposition & AV_DISPOSITION_##flag)); \
} while (0)

    PRINT_DISP(DEFAULT,          "default");
    PRINT_DISP(DUB,              "dub");
    PRINT_DISP(ORIGINAL,         "original");
    PRINT_DISP(COMMENT,          "comment");
    PRINT_DISP(LYRICS,           "lyrics");
    PRINT_DISP(KARAOKE,          "karaoke");
    PRINT_DISP(FORCED,           "forced");
    PRINT_DISP(HEARING_IMPAIRED, "hearing_impaired");
    PRINT_DISP(VISUAL_IMPAIRED,  "visual_impaired");
    PRINT_DISP(CLEAN_EFFECTS,    "clean_effects");
    PRINT_DISP(ATTACHED_PIC,     "attached_pic");
    PRINT_DISP(TIMED_THUMBNAILS, "timed_thumbnails");
    PRINT_DISP(NON_DIEGETIC,     "non_diegetic");
    PRINT_DISP(CAPTIONS,         "captions");
    PRINT_DISP(DESCRIPTIONS,     "descriptions");
    PRINT_DISP(METADATA,         "metadata");
    PRINT_DISP(DEPENDENT,        "dependent");
    PRINT_DISP(STILL_IMAGE,      "still_image");
#undef PRINT_DISP

    fprintf(f, "\n%*s}", indent, "");
}

/* Print a single stream */
static void json_print_stream(FILE *f, AVFormatContext *fmt_ctx,
                               AVStream *stream, int indent)
{
    AVCodecParameters *par = stream->codecpar;
    const AVCodecDescriptor *cd;
    const char *s;
    const char *profile;
    char val_str[128];
    int first = 1;

    fprintf(f, "%*s{\n", indent, "");
    indent += 4;

    json_print_int(f, "index", stream->index, indent, &first);

    cd = avcodec_descriptor_get(par->codec_id);
    if (cd) {
        json_print_str(f, "codec_name", cd->name, indent, &first);
        if (cd->long_name) {
            json_print_str(f, "codec_long_name", cd->long_name, indent, &first);
        }
    }

    profile = avcodec_profile_name(par->codec_id, par->profile);
    if (profile) {
        json_print_str(f, "profile", profile, indent, &first);
    } else if (par->profile != AV_PROFILE_UNKNOWN) {
        snprintf(val_str, sizeof(val_str), "%d", par->profile);
        json_print_str(f, "profile", val_str, indent, &first);
    }

    s = av_get_media_type_string(par->codec_type);
    if (s) {
        json_print_str(f, "codec_type", s, indent, &first);
    }

    json_print_str(f, "codec_tag_string", av_fourcc2str(par->codec_tag),
                   indent, &first);
    snprintf(val_str, sizeof(val_str), "0x%04"PRIx32, par->codec_tag);
    json_print_str(f, "codec_tag", val_str, indent, &first);

    switch (par->codec_type) {
    case AVMEDIA_TYPE_VIDEO: {
        AVRational sar, dar;

        json_print_int(f, "width", par->width, indent, &first);
        json_print_int(f, "height", par->height, indent, &first);

        /* Note: coded_width, coded_height, closed_captions, film_grain,
           and refs require opening a decoder context, which we skip for simplicity */

        json_print_int(f, "has_b_frames", par->video_delay, indent, &first);

        /* Sample aspect ratio */
        sar = av_guess_sample_aspect_ratio(fmt_ctx, stream, NULL);
        if (sar.num) {
            snprintf(val_str, sizeof(val_str), "%d:%d", sar.num, sar.den);
            json_print_str(f, "sample_aspect_ratio", val_str, indent, &first);

            /* Display aspect ratio */
            av_reduce(&dar.num, &dar.den,
                     par->width * sar.num,
                     par->height * sar.den,
                     1024*1024);
            snprintf(val_str, sizeof(val_str), "%d:%d", dar.num, dar.den);
            json_print_str(f, "display_aspect_ratio", val_str, indent, &first);
        }

        /* Pixel format */
        s = av_get_pix_fmt_name(par->format);
        if (s) {
            json_print_str(f, "pix_fmt", s, indent, &first);
        }

        json_print_int(f, "level", par->level, indent, &first);

        /* Color info */
        s = av_color_range_name(par->color_range);
        if (s && par->color_range != AVCOL_RANGE_UNSPECIFIED) {
            json_print_str(f, "color_range", s, indent, &first);
        }

        s = av_color_space_name(par->color_space);
        if (s && par->color_space != AVCOL_SPC_UNSPECIFIED) {
            json_print_str(f, "color_space", s, indent, &first);
        }

        s = av_color_transfer_name(par->color_trc);
        if (s && par->color_trc != AVCOL_TRC_UNSPECIFIED) {
            json_print_str(f, "color_transfer", s, indent, &first);
        }

        s = av_color_primaries_name(par->color_primaries);
        if (s && par->color_primaries != AVCOL_PRI_UNSPECIFIED) {
            json_print_str(f, "color_primaries", s, indent, &first);
        }

        s = av_chroma_location_name(par->chroma_location);
        if (s && par->chroma_location != AVCHROMA_LOC_UNSPECIFIED) {
            json_print_str(f, "chroma_location", s, indent, &first);
        }

        /* Field order */
        if (par->field_order == AV_FIELD_PROGRESSIVE) {
            json_print_str(f, "field_order", "progressive", indent, &first);
        } else if (par->field_order == AV_FIELD_TT) {
            json_print_str(f, "field_order", "tt", indent, &first);
        } else if (par->field_order == AV_FIELD_BB) {
            json_print_str(f, "field_order", "bb", indent, &first);
        } else if (par->field_order == AV_FIELD_TB) {
            json_print_str(f, "field_order", "tb", indent, &first);
        } else if (par->field_order == AV_FIELD_BT) {
            json_print_str(f, "field_order", "bt", indent, &first);
        }

        break;
    }

    case AVMEDIA_TYPE_AUDIO:
        s = av_get_sample_fmt_name(par->format);
        if (s) {
            json_print_str(f, "sample_fmt", s, indent, &first);
        }
        snprintf(val_str, sizeof(val_str), "%d", par->sample_rate);
        json_print_str(f, "sample_rate", val_str, indent, &first);
        json_print_int(f, "channels", par->ch_layout.nb_channels,
                       indent, &first);
        if (par->ch_layout.order != AV_CHANNEL_ORDER_UNSPEC) {
            av_channel_layout_describe(&par->ch_layout,
                                       val_str, sizeof(val_str));
            json_print_str(f, "channel_layout", val_str, indent, &first);
        }
        json_print_int(f, "bits_per_sample",
                       av_get_bits_per_sample(par->codec_id),
                       indent, &first);
        json_print_int(f, "initial_padding", par->initial_padding,
                       indent, &first);
        break;

    default:
        break;
    }

    /* Common fields for all stream types */
    if (fmt_ctx->iformat->flags & AVFMT_SHOW_IDS) {
        snprintf(val_str, sizeof(val_str), "0x%x", stream->id);
        json_print_str(f, "id", val_str, indent, &first);
    }

    snprintf(val_str, sizeof(val_str), "%d/%d",
             stream->r_frame_rate.num, stream->r_frame_rate.den);
    json_print_str(f, "r_frame_rate", val_str, indent, &first);

    snprintf(val_str, sizeof(val_str), "%d/%d",
             stream->avg_frame_rate.num, stream->avg_frame_rate.den);
    json_print_str(f, "avg_frame_rate", val_str, indent, &first);

    snprintf(val_str, sizeof(val_str), "%d/%d",
             stream->time_base.num, stream->time_base.den);
    json_print_str(f, "time_base", val_str, indent, &first);

    json_print_ts(f, "start_pts", stream->start_time, indent, &first);
    json_print_time(f, "start_time", stream->start_time, &stream->time_base,
                    indent, &first);
    json_print_ts(f, "duration_ts", stream->duration, indent, &first);
    json_print_duration(f, "duration", stream->duration, &stream->time_base,
                        indent, &first);

    if (par->bit_rate > 0) {
        snprintf(val_str, sizeof(val_str), "%"PRId64, par->bit_rate);
        json_print_str(f, "bit_rate", val_str, indent, &first);
    }

    if (stream->nb_frames) {
        snprintf(val_str, sizeof(val_str), "%"PRId64, stream->nb_frames);
        json_print_str(f, "nb_frames", val_str, indent, &first);
    }

    if (par->extradata_size > 0)
        json_print_int(f, "extradata_size", par->extradata_size,
                       indent, &first);

    /* Disposition */
    json_print_disposition(f, stream->disposition, indent);

    /* Tags */
    if (stream->metadata && av_dict_count(stream->metadata) > 0)
        json_print_tags(f, stream->metadata, indent);

    indent -= 4;
    fprintf(f, "\n%*s}", indent, "");
}

/* Main probe entry point */
int ffmpeg_probe_json(const char *filename)
{
    AVFormatContext *fmt_ctx = NULL;
    int err, i;
    FILE *f = stdout;
    int64_t size;
    char val_str[128];

    err = avformat_open_input(&fmt_ctx, filename, NULL, NULL);
    if (err < 0) {
        /* Print error in JSON format to match ffprobe -show_error */
        fprintf(f, "{\n");
        fprintf(f, "    \"error\": {\n");
        fprintf(f, "        \"code\": %d,\n", err);
        fprintf(f, "        \"string\": \"%s\"\n", av_err2str(err));
        fprintf(f, "    }\n");
        fprintf(f, "}\n");
        return 1;
    }

    err = avformat_find_stream_info(fmt_ctx, NULL);
    if (err < 0) {
        fprintf(f, "{\n");
        fprintf(f, "    \"error\": {\n");
        fprintf(f, "        \"code\": %d,\n", err);
        fprintf(f, "        \"string\": \"%s\"\n", av_err2str(err));
        fprintf(f, "    }\n");
        fprintf(f, "}\n");
        avformat_close_input(&fmt_ctx);
        return 1;
    }

    fprintf(f, "{\n");

    /* === Streams === */
    fprintf(f, "    \"streams\": [\n");
    for (i = 0; i < fmt_ctx->nb_streams; i++) {
        if (i > 0) fprintf(f, ",\n");
        json_print_stream(f, fmt_ctx, fmt_ctx->streams[i], 8);
    }
    fprintf(f, "\n    ]");

    /* === Chapters === */
    fprintf(f, ",\n    \"chapters\": [\n");
    for (i = 0; i < fmt_ctx->nb_chapters; i++) {
        AVChapter *ch = fmt_ctx->chapters[i];
        int first = 1;

        if (i > 0) fprintf(f, ",\n");
        fprintf(f, "        {\n");

        json_print_int(f, "id", ch->id, 12, &first);
        snprintf(val_str, sizeof(val_str), "%d/%d",
                 ch->time_base.num, ch->time_base.den);
        json_print_str(f, "time_base", val_str, 12, &first);
        json_print_int(f, "start", ch->start, 12, &first);
        json_print_time(f, "start_time", ch->start, &ch->time_base,
                        12, &first);
        json_print_int(f, "end", ch->end, 12, &first);
        json_print_time(f, "end_time", ch->end, &ch->time_base,
                        12, &first);

        if (ch->metadata && av_dict_count(ch->metadata) > 0)
            json_print_tags(f, ch->metadata, 12);

        fprintf(f, "\n        }");
    }
    fprintf(f, "\n    ]");

    /* === Format === */
    {
        int first = 1;

        fprintf(f, ",\n    \"format\": {\n");

        json_print_str(f, "filename", fmt_ctx->url, 8, &first);
        json_print_int(f, "nb_streams", fmt_ctx->nb_streams, 8, &first);
        json_print_int(f, "nb_programs", fmt_ctx->nb_programs, 8, &first);
        json_print_str(f, "format_name", fmt_ctx->iformat->name, 8, &first);
        if (fmt_ctx->iformat->long_name) {
            json_print_str(f, "format_long_name", fmt_ctx->iformat->long_name,
                           8, &first);
        }
        json_print_time(f, "start_time", fmt_ctx->start_time,
                        &AV_TIME_BASE_Q, 8, &first);
        json_print_time(f, "duration", fmt_ctx->duration,
                        &AV_TIME_BASE_Q, 8, &first);

        size = fmt_ctx->pb ? avio_size(fmt_ctx->pb) : -1;
        if (size >= 0) {
            snprintf(val_str, sizeof(val_str), "%"PRId64, size);
            json_print_str(f, "size", val_str, 8, &first);
        }

        if (fmt_ctx->bit_rate > 0) {
            snprintf(val_str, sizeof(val_str), "%"PRId64, fmt_ctx->bit_rate);
            json_print_str(f, "bit_rate", val_str, 8, &first);
        }

        json_print_int(f, "probe_score", fmt_ctx->probe_score, 8, &first);

        if (fmt_ctx->metadata && av_dict_count(fmt_ctx->metadata) > 0)
            json_print_tags(f, fmt_ctx->metadata, 8);

        fprintf(f, "\n    }");
    }

    fprintf(f, "\n}\n");

    avformat_close_input(&fmt_ctx);
    return 0;
}
