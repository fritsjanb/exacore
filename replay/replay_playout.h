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

#ifndef _REPLAY_PLAYOUT_H
#define _REPLAY_PLAYOUT_H

#include "thread.h"
#include "mutex.h"
#include "adapter.h"
#include "replay_data.h"
#include "replay_buffer.h"
#include "async_port.h"
#include "rational.h"

class ReplayPlayout : public Thread {
    public:
        ReplayPlayout(OutputAdapter *oadp_);
        ~ReplayPlayout( );

        void roll_shot(ReplayShot *shot);
        void stop( );

        AsyncPort<ReplayRawFrame> monitor;

    protected:
        void run_thread( );
        void get_and_advance_current_fields(ReplayFrameData &f1, 
                ReplayFrameData &f2, Rational &pos);

        void decode_field(RawFrame *out, ReplayFrameData &field, 
                ReplayFrameData &cache_data, RawFrame *&cache_frame,
                bool is_first_field);

        OutputAdapter *oadp;

        ReplayBuffer *current_source;
        Rational current_pos;
        Rational field_rate;

        Mutex m;

        Mjpeg422Decoder dec;
};

#endif

