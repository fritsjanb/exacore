/*
 * Copyright 2011 Exavideo LLC.
 * 
 * This file is part of openreplay.
 * 
 * openreplay is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * openreplay is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with openreplay.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "mjpeg_codec.h"
#include "libjpeg_glue.h"
#include "xmalloc.h"
#include <string.h>
#include <assert.h>

Mjpeg422Decoder::Mjpeg422Decoder(coord_t maxw_, coord_t maxh_) {
    maxw = maxw_;
    maxh = maxh_;

    /* allocate our planar YCbCr image */
    y_plane = (uint8_t *)
        xmalloc(2 * maxw * maxh, "Mjpeg422Decoder", "YCbCr planes");
    cb_plane = y_plane + maxw * maxh;
    cr_plane = cb_plane + maxw * maxh / 2;

    y_scans = (JSAMPARRAY)
        xmalloc(sizeof(JSAMPROW) * maxh, "Mjpeg422Decoder", "y_scans");
    cb_scans = (JSAMPARRAY)
        xmalloc(sizeof(JSAMPROW) * maxh, "Mjpeg422Decoder", "cb_scans");
    cr_scans = (JSAMPARRAY)
        xmalloc(sizeof(JSAMPROW) * maxh, "Mjpeg422Decoder", "cr_scans");

    for (int i = 0; i < maxh; i++) {
        y_scans[i] = (JSAMPROW) (y_plane + i * maxw);
        cb_scans[i] = (JSAMPROW) (cb_plane + i * maxw/2);
        cr_scans[i] = (JSAMPROW) (cr_plane + i * maxw/2);
    }

    libjpeg_init( );
}

Mjpeg422Decoder::~Mjpeg422Decoder( ) {
    free(y_plane);
    free(y_scans);
    free(cb_scans);
    free(cr_scans);

    jpeg_destroy_decompress(&cinfo);
}

void Mjpeg422Decoder::libjpeg_init( ) {
    memset(&cinfo, 0, sizeof(cinfo));

    cinfo.err = jpeg_throw_on_error(&jerr);
    jpeg_create_decompress(&cinfo);
}

void Mjpeg422Decoder::get_comment(std::string &com) {
    com = comment;
}

RawFrame *Mjpeg422Decoder::decode(void *data, size_t size, int scale_down) {
    JSAMPARRAY planes[3];
    JDIMENSION scanlines_produced = 0;

    jpeg_mem_src(&cinfo, data, size);
    jpeg_save_markers(&cinfo, JPEG_COM, 64);
    jpeg_read_header(&cinfo, TRUE /* require_image */);

    /* search for a JPEG comment */
    jpeg_saved_marker_ptr marker = cinfo.marker_list;

    while (marker != NULL) {
        if (marker->marker == JPEG_COM) {
            comment.assign((char *)marker->data, marker->data_length);
            break;
        }
        marker = marker->next;
    }

    cinfo.dct_method = JDCT_FASTEST;
    cinfo.raw_data_out = TRUE;

    /* less than 20, assume it's a ratio... otherwise, assume a max. width */
    if (scale_down < 20) {
        cinfo.scale_num = 1;
        cinfo.scale_denom = scale_down;
    } else {
        /* crudely fit decompressed results into specified width */
        cinfo.scale_num = 1;
        cinfo.scale_denom = 1;

        while ((int)(cinfo.image_width / cinfo.scale_denom) > scale_down) {
            cinfo.scale_denom++;
        }
    }


    if (cinfo.num_components != 3) {
        throw std::runtime_error("Mjpeg422Decoder: wrong number of components");
    }

    if (cinfo.comp_info[0].v_samp_factor != 1 
            || cinfo.comp_info[0].h_samp_factor != 2) {
        throw std::runtime_error("JPEG not in 4:2:2 format");
    }

    if (cinfo.comp_info[1].v_samp_factor != 1
            || cinfo.comp_info[1].h_samp_factor != 1) {
        throw std::runtime_error("JPEG not in 4:2:2 format");
    }

    if (cinfo.comp_info[2].v_samp_factor != 1
            || cinfo.comp_info[2].h_samp_factor != 1) {
        throw std::runtime_error("JPEG not in 4:2:2 format");
    }

    jpeg_start_decompress(&cinfo);

    if (cinfo.output_width > maxw || cinfo.output_height > maxh) {
        throw std::runtime_error("Mjpeg422Decoder: image too large");
    }

    for (unsigned int i = 0; i < cinfo.output_height; i++) {
        y_scans[i] = y_plane + i * cinfo.output_width;
        cb_scans[i] = cb_plane + i * (cinfo.output_width / 2);
        cr_scans[i] = cr_plane + i * (cinfo.output_width / 2);
    }

    while (cinfo.output_scanline < cinfo.output_height) {
        planes[0] = y_scans + scanlines_produced;
        planes[1] = cb_scans + scanlines_produced;
        planes[2] = cr_scans + scanlines_produced;
        scanlines_produced += jpeg_read_raw_data(&cinfo, planes,
                cinfo.output_height - scanlines_produced);
    }

    jpeg_finish_decompress(&cinfo);

    RawFrame *result = new RawFrame(cinfo.output_width, cinfo.output_height, 
            RawFrame::CbYCrY8422);
    result->pack->YCbCr8P422(y_plane, cb_plane, cr_plane);
    return result;
}
