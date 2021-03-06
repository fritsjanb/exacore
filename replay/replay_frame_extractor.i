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

%{
    #include "replay_frame_extractor.h"
%}

%include "typemaps.i"
%include "std_string.i"

class ReplayFrameExtractor {
    public:
        ReplayFrameExtractor( );
        ~ReplayFrameExtractor( );
        void extract_scaled_jpeg(const ReplayShot &, timecode_t, 
                std::string &OUTPUT, int);
        void extract_thumbnail_jpeg(const ReplayShot &, timecode_t, 
                std::string &OUTPUT);
        void extract_raw_jpeg(const ReplayShot &, timecode_t, 
                std::string &OUTPUT);
        void extract_raw_audio(const ReplayShot &, timecode_t, 
                std::string &OUTPUT);
};
