/*
 * Copyright 2011 Andrew H. Armenia.
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
#ifndef _OPENREPLAY_POSIX_UTIL_H
#define _OPENREPLAY_POSIX_UTIL_H

/* 
 * These read or write all of the data possible from/to the given fd.
 * Return values:
 * 1: all data read or written successfully.
 * 0: EOF encountered. Incomplete data may have been read. (only for read_all)
 * -1: An error was encountered. Check errno.
 */
ssize_t read_all(int fd, void *data, size_t size);
ssize_t write_all(int fd, void *data, size_t size);

#endif
