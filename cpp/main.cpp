#include <stdio.h>
#include <unistd.h>
#include <time.h>
#include <iostream>
#include <fstream>
#include <string>

#include "bdbmpcie.h"

#define LOG_NUM 4
const char log_file_name[LOG_NUM][100] = { "/mnt/hdd0/data/hpc4/bgl2.log",
    "/mnt/hdd0/data/hpc4/liberty2.log",
    "/mnt/hdd0/data/hpc4/spirit2.log", 
    "/mnt/hdd0/data/hpc4/Thunderbird.log"};

const char hash_file_name[100] = "./data/bgl2_hash.txt";
const char sub_hash_file_name[100] = "./data/bgl2_subtable.txt";

using namespace std;

int main(int argc, char** argv) {
    BdbmPcie* pcie = BdbmPcie::getInstance();
	uint8_t* dmabuf = (uint8_t*)pcie->dmaBuffer();

    ifstream  table_stream;
    table_stream.open(hash_file_name);
    int idx = 0;
    int val = 0;
    int i,j;

    printf("Hash upload!\n");
    fflush(stdout);
    for (i = 0; i < 256; ++i) {
        string str;
        table_stream >> str;
        cout << str << endl;
        for (j = 0; j < str.size(); ++j)
            dmabuf[idx++] = (uint8_t)str[j];
        if (str.size() < 16)
            idx += 16 - str.size();
        table_stream >> val;
        dmabuf[idx++] = (uint8_t)val;
        
        table_stream >> val;
        dmabuf[idx++] = (uint8_t)val;

        idx += 14;
    }

    pcie->userWriteWord(8, 0);

    printf("Sub Table upload!\n");
    fflush(stdout);
    ifstream sub_stream;
    sub_stream.open(sub_hash_file_name);
    idx = 16000;
    val = 0;

    for (i = 0; i < 256; ++i) {
        string str;
        sub_stream >> str;
        /* cout << str << endl; */
        for (j = 0; j < str.size(); ++j)
            dmabuf[idx++] = (uint8_t)str[j];
        if (str.size() < 16)
            idx += 16 - str.size();
        sub_stream >> val;
        dmabuf[idx++] = (uint8_t)val;
        
        idx += 15;
    }
    pcie->userWriteWord(12, 0);

    FILE *fin = fopen(log_file_name[0], "rb");
    uint32_t file_size = 0;
    uint32_t buff_size = 0;

    printf("Table uploading is done! \n");
    fflush(stdout);
    sleep(3);
    /************************ Get Result ***************************/
    uint32_t cnt[4] = {0,};
    uint32_t const_idx[4] = {0, 1600, 3200, 4800};
    uint32_t result_file_idx[4] = {0,};
    char *result_data[4];
    for (int i = 0; i < 4; ++i) {
        result_data[i] = (char *)malloc(100000 * sizeof(char));
    }

    while(1) {
        for (i = 0; i < 4; ++i) {
            uint32_t getd = pcie->userReadWord(i + 3); // Get output status
            if(cnt[i] != getd)
                pcie->userWriteWord(15 + i, getd - cnt[i]); // DMA write Request
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



    ////////////////////////////////////////////////////////////////
    
    /******************It will be removed*******************************************/
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
    for (int i = 0; i < buff_size; ++i)
        pcie->userWriteWord(4, log_data[i]);

    printf("Data sending is done \n");
    /*******************************************************************************/
    sleep(3);

    return 0;
}
