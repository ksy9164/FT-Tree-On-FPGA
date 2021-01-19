#include <stdio.h>
#include <unistd.h>
#include <time.h>
#include <iostream>
#include <fstream>
#include <string>
#include <bitset>

#include "bdbmpcie.h"

#define LOG_NUM 4
#define ID 0

const char log_file_name[LOG_NUM][100] = { "/mnt/hdd0/data/hpc4/bgl2.log",
    "/mnt/hdd0/data/hpc4/liberty2.log",
    "/mnt/hdd0/data/hpc4/spirit2.log", 
    "/mnt/hdd0/data/hpc4/Thunderbird.log"};

const char hash_file_name[LOG_NUM][100] = { "./data/bgl2_hash.txt",
    "./data/liberty2_hash.txt",
    "./data/spirit2_hash.txt", 
    "./data/Thunderbird_hash.txt"};

const char subtable_file_name[LOG_NUM][100] = { "./data/bgl2_subtable.txt",
    "./data/liberty2_subtable.txt",
    "./data/spirit2_subtable.txt", 
    "./data/Thunderbird_subtable.txt"};

using namespace std;
typedef bitset<128> bs128;

int main(int argc, char** argv) {
    BdbmPcie* pcie = BdbmPcie::getInstance();
	uint8_t* dmabuf = (uint8_t*)pcie->dmaBuffer();

    ifstream  table_stream;
    table_stream.open(hash_file_name[ID]);
    int idx = 0;
    int val = 0;
    int i,j,k;

    printf("Hash upload!\n");
    fflush(stdout);
    for (i = 0; i < 256; ++i) {
        uint32_t arr[4];
        for (j = 0; j < 4; j++) {
            uint32_t d = 0;
            table_stream >> arr[j];
        }

        for (j = 3; j >= 0; j--) {
            pcie->userWriteWord(8, arr[j]);
        }
        uint32_t sub_hash_idx;
        uint32_t svbits;
        uint32_t merged = 0;
        table_stream >> sub_hash_idx;
        table_stream >> svbits;
        svbits = svbits >> 8;
        merged = sub_hash_idx;
        merged = merged | svbits;
        pcie->userWriteWord(8, merged);
    }
    printf("Hash upload Done!\n");
    fflush(stdout);

    printf("Sub Table upload!\n");
    fflush(stdout);
    ifstream sub_stream;
    sub_stream.open(subtable_file_name[ID]);
    val = 0;
    while(!sub_stream.eof()) {
        uint32_t arr[4];
        uint32_t d;
        for (j = 0; j < 4; j++) {
            uint32_t d = 0;
            sub_stream >> arr[j];
        }
        for (j = 3; j >= 0; j--) {
            pcie->userWriteWord(12, arr[j]);
        }
        sub_stream >> d;
        pcie->userWriteWord(12, d);
    }

    printf("Sub Table uploading Done!\n");
    fflush(stdout);

    /* FILE *fin = fopen(log_file_name[ID], "rb"); */
    FILE *fin = fopen("./compressed0000.bin", "rb");
    uint32_t file_size = 0;
    uint32_t buff_size = 0;

    printf("Table uploading is done! \n");
    fflush(stdout);

    /******************It will be removed (Log data sending)*******************************************/
    /* Get file size */
    fseek(fin, 0, SEEK_END);
    file_size = ftell(fin);
    buff_size = file_size / 4;
    if (file_size % 4 != 0)
        buff_size++;
    rewind(fin);

    /* Read data from the file */
    uint32_t *log_data = (uint32_t *)malloc(buff_size * sizeof(uint32_t));
    fread(log_data, sizeof(char), file_size, fin);

    /* Put size */
    /* pcie->userWriteWord(0, file_size / 64); */
    pcie->userWriteWord(0, 1024 * 1024 / 64 - 1);

    // increasing data size (same , duplicated)
    for ( uint32_t i = 0; i < 1024*1024/4; i++ ) {
        uint32_t id = (i / 4) * 12 +  (i % 4);
        ((uint32_t*)dmabuf)[id] = log_data[i];
        ((uint32_t*)dmabuf)[id + 4] = log_data[i];
        ((uint32_t*)dmabuf)[id + 8] = log_data[i];
    }

    for (int i = 0; i < 128 * 3; ++i) {
        pcie->userWriteWord(4, 512); // 512 x 16bytes
    }

    int cnt_f = 0;
    sleep(10);
    printf("Data sending is done \n");
    fflush(stdout);
    sleep(10);
    printf("Get data from the Host! \n");
////////////////////////////data receiving////////////////////////////////////

    sleep(10);
	uint32_t outCnt = pcie->userReadWord(0);
    if (outCnt > 512) {
        pcie->userWriteWord(16, 512); // 512 x 16bytes
        outCnt = 512;
    } else 
        pcie->userWriteWord(16, outCnt); // 512 x 16bytes
    uint32_t target = 0;
    while (target + 1 <= outCnt) {
        target = pcie->userReadWord(4);
    }
    printf("Done !!!!!!!!:) \n");
    sleep(10);
    fflush(stdout);

    sleep(10);
    ////////////////////////////////////////////////////////////////
    
    sleep(3);

    return 0;
}
