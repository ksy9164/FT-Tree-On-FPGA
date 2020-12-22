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
        svbits = svbits >> 16;
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

    FILE *fin = fopen(log_file_name[ID], "rb");
    /* FILE *fin = fopen("tempdata.txt", "rb"); */
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
    pcie->userWriteWord(0, file_size);

    /* Put data */
    for (int i = 0; i < buff_size; ++i) {
        pcie->userWriteWord(4, log_data[i]);
        /* cout << i << endl; */
    }
    printf("Data sending is done \n");
    fflush(stdout);
    /**************************************************************************************************/

    /************************ Get Result ***************************/
    uint32_t cnt[4] = {0,};
    uint32_t const_idx[4] = {0, 16000, 32000, 48000};
    uint32_t result_file_idx[4] = {0,};
    char *result_data[4];
    for (int i = 0; i < 4; ++i) {
        result_data[i] = (char *)malloc(100000 * sizeof(char));
    }

    while(1) {
        for (i = 0; i < 4; ++i) {
            uint32_t getd = pcie->userReadWord(i + 3); // Get output status
            if(cnt[i] != getd)
                pcie->userWriteWord(15 + i << 4, getd - cnt[i]); // DMA write Request
            if(cnt[i] == getd)
                break;
            uint32_t response = pcie->userReadWord(0); // DMA write done!

            // Copy to the HOST
            for (j = 0; j < (getd - cnt[i]) * 16; ++j) {
                result_data[i][j + result_file_idx[i]] = (char)dmabuf[const_idx[i] + j];
            }

            result_file_idx[i] = result_file_idx[i] + (getd - cnt[i]) * 16;
            cnt[i] = getd;
        }
    }
    /**************************************************************/

    ofstream result_f[4];
    result_f[0].open("result1.txt");
    for (i = 0; i < result_file_idx[i]; ++i) {
        result_f[0] << result_data[0][i];
    }

    printf("Done :) \n");
    fflush(stdout);

    ////////////////////////////////////////////////////////////////
    
    sleep(3);

    return 0;
}
