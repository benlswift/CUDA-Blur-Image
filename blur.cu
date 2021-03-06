
#include <stdio.h>

#define CHECK(e) { int res = (e); if (res) printf("CUDA ERROR %d\n", res); }

#define CHANNEL 3
#define N 1000

struct Image {
	int width;
	int height;
	unsigned int bytes;
	unsigned char *img;
	unsigned char *dev_img;
};


//CUDA code to blur the image
//Using average of 9 bordering pixels
__global__
void blur(unsigned char* input_image, unsigned char* output_image, int width, int height) {

	const unsigned int offset = blockIdx.x*blockDim.x + threadIdx.x;
	int row = blockIdx.y*blockDim.y + threadIdx.y;//get row of pixel
	int col = blockIdx.x*blockDim.x + threadIdx.x;//get column of pixel


	int index = width * row + col;//postion of pixel in kernel
	float average;
	//unsigned int bindex = threadIdx.y*blockDim.y + threadIdx.x;
	//Sum the window pixels
	for (int i = -1; i <= 1; i++)//iterate over 3 bordering pixels in row
	{
		for (int j = 1; j >= -1; j--)//iterate over 3 bordering pixels in column
		{
			average += input_image[width * row+i + col+j];//get bordering pixel value, add to sum
		}
	}
	output_image[index] = average / 9;//output image is average of 9 pixels

}

// Reads a color PPM image file (name provided), and
// saves data in the provided Image structure. 
// The max_col_val is set to the value read from the 
// input file. This is used later for writing output image. 
int readInpImg(const char * fname, Image & source, int & max_col_val) {

	FILE *src;

	if (!(src = fopen(fname, "rb")))
	{
		printf("Couldn't open file %s for reading.\n", fname);
		return 1;
	}

	char p, s;
	fscanf(src, "%c%c\n", &p, &s);
	if (p != 'P' || s != '6')   // Is it a valid format?
	{
		printf("Not a valid PPM file (%c %c)\n", p, s);
		exit(1);
	}

	fscanf(src, "%d %d\n", &source.width, &source.height);
	fscanf(src, "%d\n", &max_col_val);

	int pixels = source.width * source.height;
	source.bytes = pixels * 3;  // 3 => colored image with r, g, and b channels 
	source.img = (unsigned char *)malloc(source.bytes);
	if (fread(source.img, sizeof(unsigned char), source.bytes, src) != source.bytes)
	{
		printf("Error reading file.\n");
		exit(1);
	}
	fclose(src);
	return 0;
}

// Write a color image into a file (name provided) using PPM file format.  
// Image structure represents the image in the memory. 
int writeOutImg(unsigned char * img, const char * fname, const Image & roted, const int max_col_val) {

	FILE *out;
	if (!(out = fopen(fname, "wb")))
	{
		printf("Couldn't open file for output.\n");
		return 1;
	}
	fprintf(out, "P6\n%d %d\n%d\n", roted.width, roted.height, max_col_val);
	if (fwrite(img, sizeof(unsigned char), roted.bytes, out) != roted.bytes)
	{
		printf("Error writing file.\n");
		return 1;
	}
	fclose(out);
	return 0;
}



int main(int argc, char **argv)
{

	unsigned char *_img;//pointers for use in cuda
	unsigned char *_output;
	unsigned char *output_image;

	if(argc != 2)
	{
		printf("Usage: exec filename\n");
		exit(1);
	}
	char *fname = argv[1];

	//Read the input file
	Image source;
	int max_col_val;
	if (readInpImg(fname, source, max_col_val) != 0)  exit(1);
	float mem = (source.width * source.height);
	mem = mem * sizeof(unsigned char);

	CHECK(cudaMalloc((void**)&_img, mem));//

	CHECK(cudaMemcpy(_img, source.img, mem, cudaMemcpyHostToDevice));

	CHECK(cudaMalloc((void**)&_output, mem));
	int wh = source.width * source.height;

	dim3 block(32, 32);//a 32x32 grid = 1024
	dim3 grid(source.width*source.height / block.x);//number of blocks is # of pixels/grid


	blur << <grid, block >> >(_img, _output,source.width,source.height);

	//get output image from GPU ready for printing
	CHECK(cudaMemcpy(output_image, _output, mem, cudaMemcpyDeviceToHost));
	// Write the output file
	//use output image from GPU as image to print
	if (writeOutImg(output_image,"roted.ppm", source, max_col_val) != 0) // For demonstration, the input file is written to a new file named "roted.ppm" 
		exit(1);

	cudaFree(_img);//free up memory dedicated to pointers
	cudaFree(_output);
	cudaFree(output_image);

	exit(0);
}
