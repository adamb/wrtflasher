# Let's build firmware to flash routers...

I want to create firmware to flash to my routers.

I have an OpenWRT One and a BerylAX 

Create a Dockerfile and use Imagebuilder

# To run

docker build -t openwrt-builder .


# ImageBuilder

The imagebuilder file is in /downloads

This is so 

# run and make the glinet_gl

make image PROFILE="glinet_gl-mt3000" PACKAGES="kmod-batman-adv batctl-default" 2>/dev/null


