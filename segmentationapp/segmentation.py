#coding=utf-8

import hiai
from hiai.nn_tensor_lib import DataType
import jpegHandler
import os
import numpy as np
import time
import cv2 as cv

OmFileName='./models/erfnet.om'
srcFileDir = './cityimage/'
dstFileDir = './Result/'
colours = './models/cityscapes19.png'


def CreateGraph(model):

	#调用get_default_graph获取默认Graph，再进行流程编排
	myGraph = hiai.hiai._global_default_graph_stack.get_default_graph()
	if myGraph is None :
		print 'get defaule graph failed'
		return None

	nntensorList=hiai.NNTensorList()

	#使用opencv 缩放图片
	resultInference = hiai.inference(nntensorList, model, None)

	if ( hiai.HiaiPythonStatust.HIAI_PYTHON_OK == myGraph.create_graph()):
		print 'create graph ok !!!!'
		return myGraph
	else :
		print 'create graph failed, please check Davinc log.'
		return None


def GraphInference(graphHandle,inputTensorList):
	if not isinstance(graphHandle,hiai.Graph) :
		print "graphHandle is not Graph object"
		return None

	resultList = graphHandle.proc(inputTensorList)
	return resultList

def main():
	inferenceModel = hiai.AIModelDescription('segmentation',OmFileName)
	# we will resize the jpeg to 256*224 to meet resnet18 requirement via opencv,	# so DVPP resizing is not needed  	
	myGraph = CreateGraph(inferenceModel)
	if myGraph is None :
		print "CreateGraph failed"
		return None

	# in this sample demo, the resnet18 model requires 256*224 images
	InWidth = 1024
	InHeight = 512

	start = time.time()
	jpegHandler.mkdirown(dstFileDir)
	pathDir =  os.listdir(srcFileDir)  
        label_colours = cv.imread(colours, 1).astype(np.uint8)

        #print label_colours
        label_colours_bgr = label_colours[..., ::-1]
	for allDir in pathDir :
		child = os.path.join('%s%s' % (srcFileDir, allDir))
		if( not jpegHandler.is_img(child) ):
			print '[info] file : ' + child + ' is not image !'
			continue 
		# read the jpeg file and resize it to required w&h, than change it to YUV format.	
		input_image = jpegHandler.jpeg2yuv(child, InWidth, InHeight)

		inputImageTensor = hiai.NNTensor(input_image,InWidth,InHeight,3,'testImage',DataType.UINT8_T, InWidth*InHeight*3/2) 
		nntensorList=hiai.NNTensorList(inputImageTensor)

		resultList = GraphInference(myGraph,nntensorList)
		if resultList is None :
			print "graph inference failed"
			continue
                resultArray = resultList[0]
                resultArray=resultArray.reshape(19,1024,512)
       
                prediction = resultArray.argmax(axis=0)      
        
                #print prediction
                prediction = np.squeeze(prediction)
                prediction = np.resize(prediction, (3,512,1024))
                prediction = prediction.transpose(1, 2, 0).astype(np.uint8)

                prediction_rgb = np.zeros(prediction.shape, dtype=np.uint8)
                cv.LUT(prediction, label_colours_bgr, prediction_rgb)

                #key = cv.waitKey(0)
                input_path_ext = child.split(".")[-1]
                input_image_name = child.split("/")[-1:][0].replace('.' + input_path_ext, '')
                out_path_im = dstFileDir + input_image_name + '_erfnet' + '.' + input_path_ext

                cv.imwrite(out_path_im, prediction_rgb)  # color images for visualization
                print allDir +' process end '

	end = time.time()
	print 'cost time ' + str((end-start)*1000) + 'ms'		
	

	hiai.hiai._global_default_graph_stack.get_default_graph().destroy()



	print '-------------------end'


if __name__ == "__main__":
	main()
